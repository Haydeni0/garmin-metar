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

        if (!view.getMetarCode().equals("Error: 500")) {
            logger.debug("Expected Error: 500, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testParseBleTimeoutError(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.onReceive(-104, null);

        if (!view.getMetarCode().equals("Error: -104")) {
            logger.debug("Expected Error: -104, got: " + view.getMetarCode());
            return false;
        }
        return true;
    }

    (:test)
    function testMissingTokenPrompt(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        view.setToken("");
        view.makeRequest();

        if (!view.getMetarCode().equals("Set Token in App Settings")) {
            logger.debug("Expected settings prompt for empty token, got: " + view.getMetarCode());
            return false;
        }
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
}
