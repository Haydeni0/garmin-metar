using Toybox.Test;
import Toybox.Application;
import Toybox.Lang;

(:test)
module ViewDataTests {

    (:test)
    function testParseVfrPayload(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var rawMetar = "EGLL 271950Z AUTO 27012KT 9999 FEW014 18/16 Q1014";
        var payload = {
            "raw" => rawMetar,
            "flight_rules" => "VFR"
        };

        view.onReceive(200, payload);

        if (!view.getMetarCode().equals(rawMetar)) {
            logger.debug("Metar text mismatch: " + view.getMetarCode());
            return false;
        }
        if (view.getFlightRules() == null || !view.getFlightRules().equals("VFR")) {
            logger.debug("Flight rules mismatch: " + view.getFlightRules());
            return false;
        }
        return true;
    }

    (:test)
    function testParseIfrPayload(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var payload = {
            "raw" => "KJFK 271951Z 04018G28KT 1/2SM R04R/2400FT +SN FZFG VV004",
            "flight_rules" => "IFR"
        };

        view.onReceive(200, payload);

        if (view.getFlightRules() == null || !view.getFlightRules().equals("IFR")) {
            logger.debug("Expected IFR, got: " + view.getFlightRules());
            return false;
        }
        return true;
    }

    (:test)
    function testParseMissingRawKey(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var payload = {
            "station" => "EGLL"
        };

        view.onReceive(200, payload);

        if (!view.getMetarCode().equals("Bad Format")) {
            logger.debug("Expected Bad Format, got: " + view.getMetarCode());
            return false;
        }
        if (view.getFlightRules() != null) {
            logger.debug("Expected null flight rules on bad format");
            return false;
        }
        return true;
    }

    (:test)
    function testParseAuthError401(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken(StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN);
        view.onReceive(401, null);

        var code = view.getMetarCode();
        if (code.find("401") == null || code.find("Check App Settings") == null) {
            logger.debug("Expected 401 and settings prompt, got: " + code);
            return false;
        }
        if (view.getFlightRules() != null) {
            logger.debug("Expected null flight rules on error");
            return false;
        }
        return true;
    }

    (:test)
    function testParseGenericHttpError(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.onReceive(500, null);

        if (!view.getMetarCode().equals("Server Error (500)\nTry Again Later")) {
            logger.debug("Expected Server Error (500), got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testParseBleTimeoutError(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.onReceive(-104, null);

        if (!view.getMetarCode().equals("Phone Disconnected\nCheck Bluetooth")) {
            logger.debug("Expected Phone Disconnected, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testRateLimit429PublicTokenMessage(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken(StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN);
        view.onReceive(429, null);

        if (!view.getMetarCode().equals("Public Limit Reached\nEnter Own Token in Settings")) {
            logger.debug("Expected public limit message, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testRateLimit429CustomTokenMessage(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken("CUSTOM_KEY_123");
        view.onReceive(429, null);

        if (!view.getMetarCode().equals("Rate Limited (429)\nWait or Check Token")) {
            logger.debug("Expected custom rate limit message, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testBleTimeoutPhoneMessage(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.onReceive(-2, null);

        if (!view.getMetarCode().equals("Phone Timeout\nOpen Garmin Connect")) {
            logger.debug("Expected phone timeout message, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testServerTimeoutNetworkMessage(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.onReceive(-3, null);

        if (!view.getMetarCode().equals("Network Timeout\nCheck Phone Internet")) {
            logger.debug("Expected network timeout for -3, got: " + view.getMetarCode());
            return false;
        }

        view.onReceive(-300, null);

        if (!view.getMetarCode().equals("Network Timeout\nCheck Phone Internet")) {
            logger.debug("Expected network timeout for -300, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testErrorPayloadsNullAndDictionaryResetsFlightRules(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.onReceive(200, {
            "raw" => "EGLL 271950Z AUTO 27012KT 9999 FEW014",
            "flight_rules" => "VFR"
        });
        if (view.getFlightRules() == null || !view.getFlightRules().equals("VFR")) {
            logger.debug("Expected flight rules VFR");
            return false;
        }

        view.onReceive(500, null);
        if (view.getFlightRules() != null) {
            logger.debug("Expected null flight rules on null error payload, got: " + view.getFlightRules());
            return false;
        }

        view.onReceive(200, {
            "raw" => "EGLL 271950Z AUTO 27012KT 9999 FEW014",
            "flight_rules" => "VFR"
        });
        if (view.getFlightRules() == null || !view.getFlightRules().equals("VFR")) {
            logger.debug("Expected flight rules VFR");
            return false;
        }

        view.onReceive(400, { "error" => "station not found" });
        if (view.getFlightRules() != null) {
            logger.debug("Expected null flight rules on dictionary error payload, got: " + view.getFlightRules());
            return false;
        }
        return true;
    }

    (:test)
    function testMissingTokenPrompt(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken("");
        view.onShow();

        if (!view.getMetarCode().equals("Using Public Token\nSet personal token in settings")) {
            logger.debug("Expected public token notice on startup, got: " + view.getMetarCode());
            return false;
        }
        if (view.getNoticeTimer() == null) {
            logger.debug("Expected notice timer to be running");
            return false;
        }
        view.onHide();
        return true;
    }

    (:test)
    function testPublicTokenStartupNoticeDisplay(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken(StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN);
        view.onShow();

        if (!view.getMetarCode().equals("Using Public Token\nSet personal token in settings")) {
            logger.debug("Expected public token notice, got: " + view.getMetarCode());
            return false;
        }
        if (view.getNoticeTimer() == null) {
            logger.debug("Expected notice timer to be running");
            return false;
        }
        view.onHide();
        return true;
    }

    (:test)
    function testConfiguredTokenBypassesStartupNotice(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("EGLL");
        view.setToken("MOCK_VFR");
        view.onShow();

        if (view.getNoticeTimer() != null) {
            logger.debug("Expected notice timer to be null for custom token");
            return false;
        }
        if (view.getRequestCountForTest() == 0) {
            logger.debug("Expected request to start immediately for custom token");
            return false;
        }
        return true;
    }

    (:test)
    function testNoticeTimeoutProceedsToRequest(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("EGLL");
        view.setToken(StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN);
        view.onShow();

        if (view.getNoticeTimer() == null) {
            logger.debug("Expected notice timer to be running");
            return false;
        }

        var prevCount = view.getRequestCountForTest();
        view.triggerNoticeTimeoutForTest();

        if (view.getNoticeTimer() != null) {
            logger.debug("Expected notice timer to be null after timeout");
            return false;
        }
        if (view.getRequestCountForTest() <= prevCount) {
            logger.debug("Expected makeRequest to be called on notice timeout");
            return false;
        }
        return true;
    }

    (:test)
    function testAuthError401RetriesWithPublicFallback(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("EGLL");
        view.setToken("CUSTOM_INVALID_KEY");

        if (!view.getActiveTokenForTest().equals("CUSTOM_INVALID_KEY")) {
            logger.debug("Expected active token to be custom key");
            return false;
        }
        if (view.getHasFallenBackForTest()) {
            logger.debug("Expected hasFallenBack to be false initially");
            return false;
        }

        // Simulate 401 response from AVWX
        view.onReceive(401, null);

        if (!view.getHasFallenBackForTest()) {
            logger.debug("Expected hasFallenBack to be true after 401");
            return false;
        }
        if (!view.getActiveTokenForTest().equals(StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN)) {
            logger.debug("Expected active token to be public default after 401");
            return false;
        }
        if (!view.getMetarCode().equals("Using Public Token\nSet personal token in settings")) {
            logger.debug("Expected public token notice on 401 fallback, got: " + view.getMetarCode());
            return false;
        }
        if (view.getNoticeTimer() == null) {
            logger.debug("Expected notice timer to be running on 401 fallback");
            return false;
        }

        view.onHide();
        return true;
    }

    (:test)
    function testMockVfrIntegration(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setStation("EGLL");
        view.setToken("MOCK_VFR");
        view.makeRequest();

        if (view.getFlightRules() == null || !view.getFlightRules().equals("VFR")) {
            logger.debug("Expected mock VFR flight rules, got: " + view.getFlightRules());
            return false;
        }
        if (view.getMetarCode().find("EGLL") == null) {
            logger.debug("Expected EGLL in mock METAR text, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testMockTafIntegration(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken("MOCK_VFR");
        view.toggleTaf();

        if (!view.isShowingTaf()) {
            logger.debug("Expected isShowingTaf to be true");
            return false;
        }
        if (view.getMetarCode().find("TAF") == null) {
            logger.debug("Expected TAF in forecast text, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testParseNullRawKeyHandledSafely(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var payload = {"raw" => null, "flight_rules" => 123};
        view.onReceive(200, payload);

        var code = view.getMetarCode();
        if (code == null || !code.equals("Bad Format")) {
            logger.debug("Expected Bad Format for null raw, got: " + code);
            return false;
        }
        if (view.getFlightRules() != null) {
            logger.debug("Expected null flight rules for non-string, got: " + view.getFlightRules());
            return false;
        }
        return true;
    }

    (:test)
    function testNonDictionary200PayloadResetsFlightRules(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        // First simulate successful VFR response
        view.onReceive(200, { "raw" => "EGLL 271950Z AUTO 27012KT 9999 FEW014", "flight_rules" => "VFR" });
        if (!"VFR".equals(view.getFlightRules())) {
            logger.debug("Expected flight rules VFR initially");
            return false;
        }

        // Now simulate 200 response with string payload instead of dictionary
        view.onReceive(200, "Unexpected Plain String Payload");
        if (view.getFlightRules() != null) {
            logger.debug("Expected flight rules to be reset to null on non-dictionary 200 response");
            return false;
        }
        if (!"Bad Format".equals(view.getMetarCode())) {
            logger.debug("Expected metar code to be Bad Format");
            return false;
        }
        return true;
    }

    (:test)
    function testInitialLayoutShowsStationLoadingString(logger as Test.Logger) as Boolean {
        var prevToken = Application.Properties.getValue("AvwxToken");
        var prevStation = Application.Properties.getValue("TargetStation");
        Application.Properties.setValue("AvwxToken", "MOCK_VFR");
        Application.Properties.setValue("TargetStation", "EGWU");
        try {
            var view = new GarminMetarView();
            var code = view.getMetarCode();
            if (!code.equals("Loading METAR: EGWU...")) {
                logger.debug("Expected initial metar code 'Loading METAR: EGWU...', got: " + code);
                return false;
            }
            return true;
        } finally {
            Application.Properties.setValue("AvwxToken", prevToken);
            Application.Properties.setValue("TargetStation", prevStation);
        }
    }

    (:test)
    function testMissingRawKeyWithValidFlightRulesResetsBadge(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        // First simulate successful VFR payload
        var validPayload = {
            "raw" => "EGLL 271950Z AUTO 27012KT 9999 FEW014",
            "flight_rules" => "VFR"
        };
        view.onReceive(200, validPayload);
        if (!"VFR".equals(view.getFlightRules())) {
            logger.debug("Expected flight rules to be VFR");
            return false;
        }

        // Now simulate corrupt payload with flight_rules present but raw missing
        var corruptPayload = {
            "flight_rules" => "VFR"
        };
        view.onReceive(200, corruptPayload);
        if (!"Bad Format".equals(view.getMetarCode())) {
            logger.debug("Expected metar code to be 'Bad Format', got: " + view.getMetarCode());
            return false;
        }
        if (view.getFlightRules() != null) {
            logger.debug("Expected flight rules to be null when raw is missing, got: " + view.getFlightRules());
            return false;
        }
        return true;
    }
}
