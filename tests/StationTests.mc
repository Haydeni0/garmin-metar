using Toybox.Test;
using Toybox.Application;
using Toybox.WatchUi;
import Toybox.Lang;

(:test)
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

    (:test)
    function testToggleTafWhileLocatingSwitchesLayout(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.initTextAreasForTest();
        view.setToken("MOCK_VFR");
        view.setStation("");

        // Initial state is METAR
        if (view.getActiveTextArea() != view.getTextAreaMetar()) {
            logger.debug("Expected active text area to be METAR");
            return false;
        }

        // Toggle while locating
        view.toggleTaf();

        if (!view.isShowingTaf()) {
            logger.debug("Expected isShowingTaf true");
            return false;
        }
        if (view.getActiveTextArea() != view.getTextAreaTaf()) {
            logger.debug("Expected active text area to be TAF");
            return false;
        }
        var code = view.getMetarCode();
        if (code == null || !code.equals("Locating closest airport...")) {
            logger.debug("Expected Locating closest airport..., got: " + code);
            return false;
        }

        // Clean up service if instantiated
        if (view.getNearbyService() != null) {
            view.getNearbyService().cancel();
        }
        return true;
    }

    class MockReentrancyService extends NearbyAirportsService {
        var searchCallCount as Number = 0;
        hidden var mSearching as Boolean = false;

        function searchNearby(callback as Method) as Void {
            searchCallCount++;
            mSearching = true;
        }

        function isSearching() as Boolean {
            return mSearching;
        }

        function cancel() as Void {
            mSearching = false;
        }
    }

    (:test)
    function testLocateClosestAirportReentrancyGuard(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("");
        var mockService = new MockReentrancyService();
        view.setNearbyServiceForTest(mockService);

        view.locateClosestAirport();
        if (mockService.searchCallCount != 1) {
            logger.debug("Expected searchCallCount 1, got: " + mockService.searchCallCount);
            return false;
        }

        // Re-entrant call while mIsLocatingClosest is true
        view.locateClosestAirport();
        if (mockService.searchCallCount != 1) {
            logger.debug("Expected searchCallCount still 1 after re-entrant call, got: " + mockService.searchCallCount);
            return false;
        }

        mockService.cancel();
        return true;
    }

    (:test)
    function testSetStationCancelsActiveGpsSearch(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("");
        view.locateClosestAirport();

        if (!view.isLocatingClosest()) {
            logger.debug("Expected isLocatingClosest true");
            return false;
        }

        // User manually sets station
        view.setStation("EGLL");

        if (view.isLocatingClosest()) {
            logger.debug("Expected isLocatingClosest false after setStation");
            return false;
        }
        if (view.getNearbyService() != null && view.getNearbyService().isSearching()) {
            logger.debug("Expected service to not be searching after setStation");
            return false;
        }
        return true;
    }

    (:test)
    function testGetStationsPreservesConfiguredOrder(logger as Test.Logger) as Boolean {
        var input = "EGWU,EGLL,EGUB,EGVO,KJFK,KLAX";
        var stations = StationUtils.getStations(input);

        if (stations.size() != 6) {
            logger.debug("Expected size 6, got: " + stations.size());
            return false;
        }
        if (!stations[0].equals("EGWU") || !stations[1].equals("EGLL") || !stations[2].equals("EGUB") ||
            !stations[3].equals("EGVO") || !stations[4].equals("KJFK") || !stations[5].equals("KLAX")) {
            logger.debug("Configured order mismatch: " + stations);
            return false;
        }
        return true;
    }

    (:test)
    function testGetStationsNullHandledSafely(logger as Test.Logger) as Boolean {
        var stations = StationUtils.getStations(null);
        if (stations.size() != 0) {
            logger.debug("Expected empty array for null listStr");
            return false;
        }
        return true;
    }

    (:test)
    function testMenuReturnTriggersSingleRequest(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        try {
            var view = new GarminMetarView();
            var delegate = new StationMenuDelegate(view);
            view.setStation("EGLL");
            view.onShow(); // First fetch
            var reqCountBefore = view.getRequestCountForTest();

            var item = new WatchUi.MenuItem("EGLL", null, "EGLL", null);
            // Selecting station marks needsRefresh but does NOT fire makeRequest directly
            delegate.onSelect(item);
            if (view.getRequestCountForTest() != reqCountBefore) {
                logger.debug("Expected onSelect to not issue makeRequest directly");
                return false;
            }
            if (!view.getNeedsRefreshForTest()) {
                logger.debug("Expected needsRefresh to be true after station selection");
                return false;
            }

            // Returning to view via onShow triggers exactly one fetch and resets needsRefresh
            view.onShow();
            if (view.getRequestCountForTest() != reqCountBefore + 1) {
                logger.debug("Expected exactly one request triggered by onShow, got: " + (view.getRequestCountForTest() - reqCountBefore));
                return false;
            }
            if (view.getNeedsRefreshForTest()) {
                logger.debug("Expected needsRefresh to be false after onShow fetch");
                return false;
            }

            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }

    (:test)
    function testMenuCancelDoesNotTriggerDuplicateRequest(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        try {
            var view = new GarminMetarView();
            view.setStation("EGLL");
            view.onShow(); // Initial fetch; needsRefresh becomes false
            var reqCountBefore = view.getRequestCountForTest();

            // Simulate returning to view after user pressed Back in menu without selecting
            view.onShow();
            if (view.getRequestCountForTest() != reqCountBefore) {
                logger.debug("Expected onShow to not initiate request when needsRefresh is false");
                return false;
            }
            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }

    (:test)
    function testStationReselectionTriggersRefresh(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        try {
            var view = new GarminMetarView();
            view.setStation("EGLL");
            view.onShow(); // Fresh

            // Re-select same station
            view.setStation("EGLL");
            if (!view.getNeedsRefreshForTest()) {
                logger.debug("Expected needsRefresh true on same-station reselection");
                return false;
            }
            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }
}


