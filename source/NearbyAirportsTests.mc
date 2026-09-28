using Toybox.Test;
using Toybox.WatchUi;
import Toybox.Lang;

module NearbyAirportsTests {

    (:test)
    function testParseNearbyResponseNested(logger as Test.Logger) as Boolean {
        var rawData = [
            {
                "station" => {
                    "icao" => "EGLL",
                    "name" => "London Heathrow"
                },
                "distance" => 4.2
            },
            {
                "station" => {
                    "icao" => "EGWU",
                    "name" => "RAF Northolt"
                },
                "distance" => 6.1
            }
        ];

        var parsed = NearbyAirportsService.parseNearbyResponse(rawData);
        if (parsed.size() != 2) {
            logger.debug("Expected 2 parsed airports, got: " + parsed.size());
            return false;
        }

        var first = parsed[0];
        if (!first[:icao].equals("EGLL") || !first[:name].equals("London Heathrow") || first[:distance] != 4.2) {
            logger.debug("First airport parsed incorrectly: " + first);
            return false;
        }

        var second = parsed[1];
        if (!second[:icao].equals("EGWU") || !second[:name].equals("RAF Northolt") || second[:distance] != 6.1) {
            logger.debug("Second airport parsed incorrectly: " + second);
            return false;
        }

        return true;
    }

    (:test)
    function testParseNearbyResponseFlat(logger as Test.Logger) as Boolean {
        var rawData = [
            {
                "icao" => "KJFK",
                "name" => "JFK Airport",
                "distance" => 12.3
            }
        ];

        var parsed = NearbyAirportsService.parseNearbyResponse(rawData);
        if (parsed.size() != 1) {
            logger.debug("Expected 1 parsed airport, got: " + parsed.size());
            return false;
        }

        var first = parsed[0];
        if (!first[:icao].equals("KJFK") || !first[:name].equals("JFK Airport") || first[:distance] != 12.3) {
            logger.debug("Airport parsed incorrectly: " + first);
            return false;
        }

        return true;
    }

    (:test)
    function testParseNearbyResponseClampedToFive(logger as Test.Logger) as Boolean {
        var rawData = [];
        for (var i = 0; i < 8; i++) {
            rawData.add({
                "icao" => "KST" + i,
                "name" => "Station " + i,
                "distance" => (i * 5.0).toFloat()
            });
        }

        var parsed = NearbyAirportsService.parseNearbyResponse(rawData);
        if (parsed.size() != 5) {
            logger.debug("Expected 5 parsed airports, got: " + parsed.size());
            return false;
        }

        return true;
    }

    (:test)
    function testParseNearbyResponseEmpty(logger as Test.Logger) as Boolean {
        var parsed = NearbyAirportsService.parseNearbyResponse([]);
        if (parsed.size() != 0) {
            logger.debug("Expected 0 parsed airports for empty input");
            return false;
        }
        return true;
    }

    (:test)
    function testMockNearbyAirports(logger as Test.Logger) as Boolean {
        var mockList = NearbyAirportsService.getMockNearbyAirports();
        if (mockList.size() != 5) {
            logger.debug("Expected 5 mock nearby airports, got: " + mockList.size());
            return false;
        }

        for (var i = 0; i < mockList.size(); i++) {
            var item = mockList[i];
            if (!item.hasKey(:icao) || item[:icao].length() < 3) {
                logger.debug("Invalid ICAO in mock airport " + i);
                return false;
            }
            if (!item.hasKey(:distance) || item[:distance] <= 0) {
                logger.debug("Invalid distance in mock airport " + i);
                return false;
            }
        }

        return true;
    }

    (:test)
    function testNearbyMenuDelegatePopulatesItems(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var menu = new WatchUi.Menu2({:title => "Nearby Airports"});
        menu.addItem(new WatchUi.MenuItem("Searching...", null, "STATUS_SEARCHING", null));

        var delegate = new NearbyMenuDelegate(view, menu);
        var mockAirports = NearbyAirportsService.getMockNearbyAirports();

        delegate.onNearbyResult(true, mockAirports);

        if (!delegate.isLoaded()) {
            logger.debug("Expected delegate to be marked as loaded");
            return false;
        }

        // Searching item should be deleted, replaced by 5 airport items
        if (menu.findItemById("STATUS_SEARCHING") != -1) {
            logger.debug("Expected STATUS_SEARCHING to be removed from menu");
            return false;
        }

        if (menu.findItemById("EGLL") == -1) {
            logger.debug("Expected EGLL item to be in menu");
            return false;
        }

        return true;
    }

    (:test)
    function testNearbyMenuDelegateErrorHandling(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var menu = new WatchUi.Menu2({:title => "Nearby Airports"});
        menu.addItem(new WatchUi.MenuItem("Searching...", null, "STATUS_SEARCHING", null));

        var delegate = new NearbyMenuDelegate(view, menu);
        delegate.onNearbyResult(false, "No GPS Fix");

        if (delegate.isLoaded()) {
            logger.debug("Expected delegate to NOT be loaded on error");
            return false;
        }

        if (menu.findItemById("STATUS_SEARCHING") != -1) {
            logger.debug("Expected STATUS_SEARCHING to be removed");
            return false;
        }

        if (menu.findItemById("ACTION_RETRY") == -1) {
            logger.debug("Expected ACTION_RETRY to be present on error");
            return false;
        }

        return true;
    }

    (:test)
    function testStationMenuDelegateSelectsNearby(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var initialStation = view.getStation();
        var delegate = new StationMenuDelegate(view);
        var item = new WatchUi.MenuItem("Nearby Airports", null, "ACTION_NEARBY", null);

        delegate.onSelect(item);

        if (!view.getStation().equals(initialStation)) {
            logger.debug("Selecting ACTION_NEARBY must not change view station");
            return false;
        }

        return true;
    }
}
