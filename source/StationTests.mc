using Toybox.Test;
using Toybox.Application;
import Toybox.Lang;

module StationTests {

    (:test)
    function testParseSimpleList(logger) {
        var input = "A,B,C";
        var actual = StationUtils.parseStationString(input);
        
        if (actual.size() != 3) {
            logger.debug("Size mismatch: " + actual.size());
            return false;
        }
        
        if (!actual[0].equals("A")) { return false; }
        if (!actual[1].equals("B")) { return false; }
        if (!actual[2].equals("C")) { return false; }
        
        return true;
    }
    
    (:test)
    function testParseWithSpaces(logger) {
        var input = "  EGWU , KJFK  ,  A  ";
        var actual = StationUtils.parseStationString(input);
        
        if (actual.size() != 3) {
            logger.debug("Size mismatch: " + actual.size());
            return false;
        }
        
        if (!actual[0].equals("EGWU")) { 
            logger.debug("0 mismatch: '" + actual[0] + "'");
            return false; 
        }
        if (!actual[1].equals("KJFK")) { 
            logger.debug("1 mismatch: '" + actual[1] + "'");
            return false; 
        }
        if (!actual[2].equals("A")) { 
            logger.debug("2 mismatch: '" + actual[2] + "'");
            return false; 
        }
        
        return true;
    }

    (:test)
    function testUnsetTargetStationTriggersClosestAirport(logger as Test.Logger) as Boolean {
        var origToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");

        var view = new GarminMetarView();
        view.setStation("");
        view.makeRequest();

        var station = view.getStation();
        var flightRules = view.getFlightRules();
        var metarCode = view.getMetarCode();

        Application.Properties.setValue("AvwxToken", origToken != null ? origToken : "YOUR_TOKEN_HERE");

        if (!station.equals("EGLL")) {
            logger.debug("Expected station EGLL from closest airport mock, got: " + station);
            return false;
        }
        if (flightRules == null || !flightRules.equals("VFR")) {
            logger.debug("Expected VFR flight rules, got: " + flightRules);
            return false;
        }
        if (metarCode.find("EGLL") == null) {
            logger.debug("Expected EGLL in METAR text, got: " + metarCode);
            return false;
        }
        return true;
    }

    (:test)
    function testClosestAirportFailureShowsFallback(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("");
        view.onClosestAirportResult(false, "No GPS Fix");

        if (!view.getMetarCode().equals("No GPS Fix\nSelect Station")) {
            logger.debug("Expected fallback prompt on GPS failure, got: " + view.getMetarCode());
            return false;
        }
        if (!view.getStation().equals("")) {
            logger.debug("Expected empty station on GPS failure, got: " + view.getStation());
            return false;
        }
        return true;
    }

    (:test)
    function testUnsetTargetStationPropertyDefaultsToClosest(logger as Test.Logger) as Boolean {
        var origToken = Application.Properties.getValue("AvwxToken");
        var origStation = Application.Properties.getValue("TargetStation");

        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        Application.Properties.setValue("TargetStation", "");

        var view = new GarminMetarView();
        var initialStation = view.getStation();
        view.makeRequest();
        var finalStation = view.getStation();

        Application.Properties.setValue("AvwxToken", origToken != null ? origToken : "YOUR_TOKEN_HERE");
        Application.Properties.setValue("TargetStation", origStation != null ? origStation : "EGWU");

        if (!initialStation.equals("")) {
            logger.debug("Expected initial empty station when TargetStation is blank, got: " + initialStation);
            return false;
        }
        if (!finalStation.equals("EGLL")) {
            logger.debug("Expected closest airport EGLL loaded, got: " + finalStation);
            return false;
        }
        return true;
    }

    (:test)
    function testManualSelectionDuringLocatingIsNotOverwritten(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("");
        view.setStation("KJFK");

        // Simulate delayed GPS callback arriving after user manual selection
        view.onClosestAirportResult(true, [{:icao => "EGLL", :distance => 4.2}]);

        if (!view.getStation().equals("KJFK")) {
            logger.debug("Expected manual station KJFK to be preserved, got: " + view.getStation());
            return false;
        }
        return true;
    }
}
