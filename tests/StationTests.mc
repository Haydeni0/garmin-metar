using Toybox.Test;
using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Time;
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

    (:test)
    function testStaleResponseIgnoredOnStationChange(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        // Use a non-MOCK token so makeRequest() does not resolve synchronously
        Application.Properties.setValue("AvwxToken", "VALID_LIVE_TOKEN_FOR_TEST");
        try {
            var view = new GarminMetarView();
            view.setStation("EGLL");
            view.makeRequest(); // Request ID 1 (in flight)
            var firstReqId = view.getCurrentRequestIdForTest();

            if (!view.getIsRequestInFlightForTest()) {
                logger.debug("Expected request 1 to be in flight");
                return false;
            }

            // User switches to EGWU while first request is in flight
            view.setStation("EGWU");
            view.makeRequest(); // Request ID 2 (supersedes request 1)
            var secondReqId = view.getCurrentRequestIdForTest();

            if (secondReqId <= firstReqId) {
                logger.debug("Expected second request ID to be greater than first");
                return false;
            }

            // Simulate delayed arrival of response for first request (EGLL)
            var stalePayload = {
                "raw" => "EGLL 271950Z AUTO 27012KT 9999 FEW014",
                "flight_rules" => "VFR"
            };
            view.handleWebResponse(200, stalePayload, firstReqId);

            // Active view must NOT adopt stale EGLL payload
            var code = view.getMetarCode();
            if (code.find("EGLL") != null) {
                logger.debug("Stale response was not discarded; view code: " + code);
                return false;
            }
            if (!code.equals("Loading METAR: EGWU...")) {
                logger.debug("Expected loading text for EGWU, got: " + code);
                return false;
            }
            if (view.getFlightRules() != null) {
                logger.debug("Expected flight rules to remain null while waiting for station B");
                return false;
            }
            // Request 2 must still be tracked as in flight
            if (!view.getIsRequestInFlightForTest()) {
                logger.debug("Expected request 2 to remain in flight after stale response dropped");
                return false;
            }

            // Now deliver response for second request (EGWU)
            var freshPayload = {
                "raw" => "EGWU 271950Z 24008KT 9999 CAVOK",
                "flight_rules" => "VFR"
            };
            view.handleWebResponse(200, freshPayload, secondReqId);
            if (!view.getMetarCode().equals("EGWU 271950Z 24008KT 9999 CAVOK")) {
                logger.debug("Fresh response not applied; got: " + view.getMetarCode());
                return false;
            }
            if (view.getIsRequestInFlightForTest()) {
                logger.debug("Expected request in flight to be false after matching response");
                return false;
            }

            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }

    (:test)
    function testStationUtilsGetActiveTokenWithCustom(logger as Test.Logger) as Boolean {
        var token = StationUtils.getActiveToken("CUSTOM_TOKEN_123");
        if (!token.equals("CUSTOM_TOKEN_123")) {
            logger.debug("Expected CUSTOM_TOKEN_123, got: " + token);
            return false;
        }
        return true;
    }

    (:test)
    function testStationUtilsGetActiveTokenWithBlankAndNull(logger as Test.Logger) as Boolean {
        var expected = StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN;

        var tokenNull = StationUtils.getActiveToken(null);
        if (!tokenNull.equals(expected)) {
            logger.debug("Expected public token for null, got: " + tokenNull);
            return false;
        }

        var tokenEmpty = StationUtils.getActiveToken("");
        if (!tokenEmpty.equals(expected)) {
            logger.debug("Expected public token for empty string, got: " + tokenEmpty);
            return false;
        }

        var tokenPlaceholder = StationUtils.getActiveToken("YOUR_TOKEN_HERE");
        if (!tokenPlaceholder.equals(expected)) {
            logger.debug("Expected public token for placeholder, got: " + tokenPlaceholder);
            return false;
        }

        return true;
    }

    (:test)
    function testStationUtilsIsPublicDefaultToken(logger as Test.Logger) as Boolean {
        if (!StationUtils.isPublicDefaultToken(null)) {
            logger.debug("Expected null to be public default token");
            return false;
        }
        if (!StationUtils.isPublicDefaultToken("")) {
            logger.debug("Expected empty string to be public default token");
            return false;
        }
        if (!StationUtils.isPublicDefaultToken("YOUR_TOKEN_HERE")) {
            logger.debug("Expected placeholder to be public default token");
            return false;
        }
        if (!StationUtils.isPublicDefaultToken(StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN)) {
            logger.debug("Expected DEFAULT_PUBLIC_AVWX_TOKEN to be public default token");
            return false;
        }
        if (StationUtils.isPublicDefaultToken("CUSTOM_KEY")) {
            logger.debug("Expected CUSTOM_KEY to not be public default token");
            return false;
        }

        if (StationUtils.isConfiguredCustomToken(null)) {
            logger.debug("Expected null to not be configured custom token");
            return false;
        }
        if (StationUtils.isConfiguredCustomToken("")) {
            logger.debug("Expected empty string to not be configured custom token");
            return false;
        }
        if (!StationUtils.isConfiguredCustomToken("CUSTOM_KEY")) {
            logger.debug("Expected CUSTOM_KEY to be configured custom token");
            return false;
        }

        return true;
    }

    (:test)
    function testStationUtilsAbsVal(logger as Test.Logger) as Boolean {
        var negVal = StationUtils.absVal(-12.34);
        if (negVal < 12.339 || negVal > 12.341) {
            logger.debug("Expected 12.34 for -12.34, got: " + negVal);
            return false;
        }

        var zeroVal = StationUtils.absVal(0.0);
        if (zeroVal != 0.0) {
            logger.debug("Expected 0.0 for 0.0, got: " + zeroVal);
            return false;
        }

        var posVal = StationUtils.absVal(56.78);
        if (posVal < 56.779 || posVal > 56.781) {
            logger.debug("Expected 56.78 for 56.78, got: " + posVal);
            return false;
        }

        return true;
    }

    (:test)
    function testStationUtilsFormatErrorMessageCatalog(logger as Test.Logger) as Boolean {
        if (!StationUtils.formatErrorMessage(-104, true).equals("Phone Disconnected\nCheck Bluetooth")) {
            logger.debug("Mismatch for -104: " + StationUtils.formatErrorMessage(-104, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(-2, true).equals("Phone Timeout\nOpen Garmin Connect")) {
            logger.debug("Mismatch for -2: " + StationUtils.formatErrorMessage(-2, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(-3, true).equals("Network Timeout\nCheck Phone Internet")) {
            logger.debug("Mismatch for -3: " + StationUtils.formatErrorMessage(-3, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(-300, true).equals("Network Timeout\nCheck Phone Internet")) {
            logger.debug("Mismatch for -300: " + StationUtils.formatErrorMessage(-300, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(-101, true).equals("Bluetooth Busy\nTry Again")) {
            logger.debug("Mismatch for -101: " + StationUtils.formatErrorMessage(-101, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(-400, true).equals("Response Too Large")) {
            logger.debug("Mismatch for -400: " + StationUtils.formatErrorMessage(-400, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(-999, true).equals("Connection Error (-999)")) {
            logger.debug("Mismatch for -999: " + StationUtils.formatErrorMessage(-999, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(400, true).equals("Invalid Request (400)")) {
            logger.debug("Mismatch for 400: " + StationUtils.formatErrorMessage(400, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(401, true).equals("Token Invalid (401)\nCheck App Settings")) {
            logger.debug("Mismatch for 401: " + StationUtils.formatErrorMessage(401, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(403, true).equals("Public Limit Reached\nEnter Own Token in Settings")) {
            logger.debug("Mismatch for 403 public: " + StationUtils.formatErrorMessage(403, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(403, false).equals("Rate Limited (403)\nWait or Check Token")) {
            logger.debug("Mismatch for 403 custom: " + StationUtils.formatErrorMessage(403, false));
            return false;
        }
        if (!StationUtils.formatErrorMessage(404, true).equals("Station Not Found\nVerify ICAO Code (404)")) {
            logger.debug("Mismatch for 404: " + StationUtils.formatErrorMessage(404, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(429, true).equals("Public Limit Reached\nEnter Own Token in Settings")) {
            logger.debug("Mismatch for 429 public: " + StationUtils.formatErrorMessage(429, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(429, false).equals("Rate Limited (429)\nWait or Check Token")) {
            logger.debug("Mismatch for 429 custom: " + StationUtils.formatErrorMessage(429, false));
            return false;
        }
        if (!StationUtils.formatErrorMessage(500, true).equals("Server Error (500)\nTry Again Later")) {
            logger.debug("Mismatch for 500: " + StationUtils.formatErrorMessage(500, true));
            return false;
        }
        if (!StationUtils.formatErrorMessage(502, false).equals("Server Error (502)\nTry Again Later")) {
            logger.debug("Mismatch for 502: " + StationUtils.formatErrorMessage(502, false));
            return false;
        }
        return true;
    }

    (:test)
    function testStationUtilsFormatNearbyErrorMessageCatalog(logger as Test.Logger) as Boolean {
        if (!StationUtils.formatNearbyErrorMessage(-104, true).equals("Phone Disconnected")) {
            logger.debug("Nearby mismatch for -104: " + StationUtils.formatNearbyErrorMessage(-104, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(-2, true).equals("Network Timeout")) {
            logger.debug("Nearby mismatch for -2: " + StationUtils.formatNearbyErrorMessage(-2, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(-3, true).equals("Network Timeout")) {
            logger.debug("Nearby mismatch for -3: " + StationUtils.formatNearbyErrorMessage(-3, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(-300, true).equals("Network Timeout")) {
            logger.debug("Nearby mismatch for -300: " + StationUtils.formatNearbyErrorMessage(-300, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(401, true).equals("Token Invalid")) {
            logger.debug("Nearby mismatch for 401: " + StationUtils.formatNearbyErrorMessage(401, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(403, true).equals("Limit Reached")) {
            logger.debug("Nearby mismatch for 403: " + StationUtils.formatNearbyErrorMessage(403, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(429, true).equals("Limit Reached")) {
            logger.debug("Nearby mismatch for 429: " + StationUtils.formatNearbyErrorMessage(429, true));
            return false;
        }
        if (!StationUtils.formatNearbyErrorMessage(500, true).equals("Error: 500")) {
            logger.debug("Nearby mismatch for 500: " + StationUtils.formatNearbyErrorMessage(500, true));
            return false;
        }
        return true;
    }

    (:test)
    function testWeatherCachePreventsDuplicateRequest(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        try {
            var view = new GarminMetarView();
            view.setStation("EGLL");
            var cachedReport = "EGLL CACHED METAR 9999 CAVOK";
            view.setCacheEntryForTest("EGLL", false, cachedReport, "VFR", Time.now().value());

            var prevReqCount = view.getRequestCountForTest();
            var prevReqId = view.getCurrentRequestIdForTest();

            view.makeRequest();

            if (view.getRequestCountForTest() != prevReqCount) {
                logger.debug("Expected request count not to advance on cache hit; prev: " + prevReqCount + " now: " + view.getRequestCountForTest());
                return false;
            }
            if (view.getCurrentRequestIdForTest() != prevReqId) {
                logger.debug("Expected request ID not to advance on cache hit; prev: " + prevReqId + " now: " + view.getCurrentRequestIdForTest());
                return false;
            }
            if (!view.getMetarCode().equals(cachedReport)) {
                logger.debug("Expected cached METAR code, got: " + view.getMetarCode());
                return false;
            }
            if (view.getFlightRules() == null || !view.getFlightRules().equals("VFR")) {
                logger.debug("Expected VFR flight rules from cache, got: " + view.getFlightRules());
                return false;
            }
            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }

    (:test)
    function testWeatherCacheTtlExpiration(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        try {
            var view = new GarminMetarView();
            view.setStation("EGLL");
            var expiredReport = "EGLL EXPIRED METAR";
            var expiredTimestamp = Time.now().value() - 301;
            view.setCacheEntryForTest("EGLL", false, expiredReport, "VFR", expiredTimestamp);

            var prevReqCount = view.getRequestCountForTest();

            view.makeRequest();

            if (view.getRequestCountForTest() != prevReqCount + 1) {
                logger.debug("Expected request count to increment on cache miss; prev: " + prevReqCount + " now: " + view.getRequestCountForTest());
                return false;
            }
            if (view.getMetarCode().equals(expiredReport)) {
                logger.debug("Expected expired cache entry to be bypassed, got cached report");
                return false;
            }
            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }

    (:test)
    function testStationReselectionInvalidatesCache(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        try {
            var view = new GarminMetarView();
            view.setStation("EGLL");
            view.setCacheEntryForTest("EGLL", false, "EGLL CACHED METAR", "VFR", Time.now().value());
            view.setCacheEntryForTest("EGLL", true, "EGLL CACHED TAF", null, Time.now().value());

            if (!view.hasValidCacheEntry("EGLL", false)) {
                logger.debug("Expected valid cache entry before reselection");
                return false;
            }
            if (!view.hasValidCacheEntry("EGLL", true)) {
                logger.debug("Expected valid TAF cache entry before reselection");
                return false;
            }

            view.setStation("EGLL");

            if (view.hasValidCacheEntry("EGLL", false)) {
                logger.debug("Expected METAR cache entry to be invalidated on station reselection");
                return false;
            }
            if (view.hasValidCacheEntry("EGLL", true)) {
                logger.debug("Expected TAF cache entry to be invalidated on station reselection");
                return false;
            }
            if (!view.getNeedsRefreshForTest()) {
                logger.debug("Expected needsRefresh to be true on station reselection");
                return false;
            }
            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
        }
    }
}


