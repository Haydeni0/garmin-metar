using Toybox.Test;
using Toybox.WatchUi;
using Toybox.Position;
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
    function testParseNearbyResponseNauticalMiles(logger as Test.Logger) as Boolean {
        // Real AVWX API response structure with nautical_miles key
        var rawData = [
            {
                "nautical_miles" => 18.78,
                "station" => {
                    "icao" => "KMLB",
                    "name" => "Melbourne International Airport"
                }
            }
        ];

        var parsed = NearbyAirportsService.parseNearbyResponse(rawData);
        if (parsed.size() != 1) {
            logger.debug("Expected 1 parsed airport, got: " + parsed.size());
            return false;
        }

        var first = parsed[0];
        if (!first[:icao].equals("KMLB") || first[:distance] == null || first[:distance] < 18.7 || first[:distance] > 18.8) {
            logger.debug("Airport distance parsed incorrectly from nautical_miles: " + first);
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

        var egllIdx = menu.findItemById("EGLL");
        if (egllIdx == -1 || egllIdx == null) {
            logger.debug("Expected EGLL item to be in menu");
            return false;
        }
        var egllItem = menu.getItem(egllIdx);
        if (!egllItem.getLabel().equals("EGLL (4.2nm)")) {
            logger.debug("Expected label 'EGLL (4.2nm)', got: " + egllItem.getLabel());
            return false;
        }
        if (!egllItem.getSubLabel().equals("Heathrow")) {
            logger.debug("Expected sublabel 'Heathrow', got: " + egllItem.getSubLabel());
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

    (:test)
    function testCoordinateValidation(logger as Test.Logger) as Boolean {
        // Valid coordinates
        if (!NearbyAirportsService.isValidCoordinate(51.5074, -0.1278)) {
            logger.debug("Valid London coordinate rejected");
            return false;
        }
        if (!NearbyAirportsService.isValidCoordinate(-33.8688, 151.2093)) {
            logger.debug("Valid Sydney coordinate rejected");
            return false;
        }

        // Invalid: Garmin uninitialized fix sentinel [180.0, 180.0]
        if (NearbyAirportsService.isValidCoordinate(180.0, 180.0)) {
            logger.debug("Garmin no-fix sentinel 180,180 should be rejected");
            return false;
        }

        // Invalid: Latitude bounds (> 90 or < -90)
        if (NearbyAirportsService.isValidCoordinate(90.1, 0.0) || NearbyAirportsService.isValidCoordinate(-90.1, 0.0)) {
            logger.debug("Out of range latitude should be rejected");
            return false;
        }

        // Invalid: Longitude bounds (> 180 or < -180)
        if (NearbyAirportsService.isValidCoordinate(0.0, 180.1) || NearbyAirportsService.isValidCoordinate(0.0, -180.1)) {
            logger.debug("Out of range longitude should be rejected");
            return false;
        }

        return true;
    }

    (:test)
    function testSimulatorUninitializedLocationRejected(logger as Test.Logger) as Boolean {
        var info = Position.getInfo();
        // Simulator starts with no GPS fix (QUALITY_NOT_AVAILABLE or [180, 180])
        var valid = NearbyAirportsService.isValidLocation(info);
        if (valid) {
            logger.debug("Default uninitialized simulator position should not be treated as valid GPS fix");
            return false;
        }
        return true;
    }

    class MockNearbyCallbackReceiver {
        public var mSuccess as Boolean = false;
        public var mData as Object or Null = null;
        public var mCallCount as Number = 0;

        function onResult(success as Boolean, data as Object) as Void {
            mSuccess = success;
            mData = data;
            mCallCount++;
        }
    }

    (:test)
    function testGpsTimeoutTriggersError(logger as Test.Logger) as Boolean {
        var service = new NearbyAirportsService();
        var receiver = new MockNearbyCallbackReceiver();
        service.searchNearby(receiver.method(:onResult));

        // Trigger timeout handler
        service.onGpsTimeout();

        if (receiver.mCallCount != 1) {
            logger.debug("Expected 1 callback, got: " + receiver.mCallCount);
            return false;
        }
        if (receiver.mSuccess != false) {
            logger.debug("Expected failure on GPS timeout");
            return false;
        }
        if (receiver.mData == null || !(receiver.mData as String).equals("No GPS Fix")) {
            logger.debug("Expected 'No GPS Fix', got: " + receiver.mData);
            return false;
        }
        return true;
    }

    (:test)
    function testFetchFromAvwxRejectsSentinelCoordinates(logger as Test.Logger) as Boolean {
        var service = new NearbyAirportsService();
        var receiver = new MockNearbyCallbackReceiver();
        service.searchNearby(receiver.method(:onResult));

        // Call fetchFromAvwx with Garmin uninitialized sentinel 180, 180
        service.fetchFromAvwx(180.0, 180.0);

        if (receiver.mSuccess != false || receiver.mData == null || !(receiver.mData as String).equals("No GPS Fix")) {
            logger.debug("Expected 'No GPS Fix' for sentinel coordinates 180,180, got: " + receiver.mData);
            return false;
        }
        return true;
    }

    (:test)
    function testFetchFromAvwxRejectsOutOfBoundsCoordinates(logger as Test.Logger) as Boolean {
        var service = new NearbyAirportsService();
        var receiver = new MockNearbyCallbackReceiver();
        service.searchNearby(receiver.method(:onResult));

        // Call fetchFromAvwx with invalid latitude 95.0
        service.fetchFromAvwx(95.0, 0.0);

        if (receiver.mSuccess != false || receiver.mData == null || !(receiver.mData as String).equals("No GPS Fix")) {
            logger.debug("Expected 'No GPS Fix' for out of bounds latitude, got: " + receiver.mData);
            return false;
        }
        return true;
    }

    (:test)
    function testParseCoordinates(logger as Test.Logger) as Boolean {
        var parsed = NearbyAirportsService.parseCoordinates("51.5074,-0.1278");
        if (parsed == null || parsed.size() != 2) {
            logger.debug("Failed to parse valid coordinates");
            return false;
        }
        if (parsed[0] < 51.50 || parsed[0] > 51.51 || parsed[1] > -0.12 || parsed[1] < -0.13) {
            logger.debug("Parsed values incorrect: " + parsed);
            return false;
        }

        // Invalid strings
        if (NearbyAirportsService.parseCoordinates("") != null) {
            logger.debug("Empty string should return null");
            return false;
        }
        if (NearbyAirportsService.parseCoordinates("invalid") != null) {
            logger.debug("No comma string should return null");
            return false;
        }
        if (NearbyAirportsService.parseCoordinates("abc,def") != null) {
            logger.debug("Non-numeric string should return null");
            return false;
        }

        return true;
    }
}
