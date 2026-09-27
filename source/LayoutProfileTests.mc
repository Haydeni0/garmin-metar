using Toybox.Test;
import Toybox.Lang;
import Toybox.System;
import Toybox.Graphics;

module LayoutProfileTests {

    (:test)
    function testInstinctProfile(logger as Test.Logger) as Boolean {
        var profile = new LayoutProfile(null, null);
        profile.applyConfiguration(176, 176, System.SCREEN_SHAPE_SEMI_OCTAGON, 24);

        if (profile.shape != :semi_octagon) {
            logger.debug("Shape mismatch: " + profile.shape);
            return false;
        }
        if (!profile.hasSubscreen) {
            logger.debug("Expected hasSubscreen to be true");
            return false;
        }
        if (!profile.hasHeader) {
            logger.debug("Expected hasHeader to be true");
            return false;
        }
        if (profile.contentY != 68) {
            logger.debug("Expected contentY 68, got " + profile.contentY);
            return false;
        }
        if (profile.contentHeight != 108) {
            logger.debug("Expected contentHeight 108, got " + profile.contentHeight);
            return false;
        }
        if (profile.subscreenCenterX != 144 || profile.subscreenCenterY != 31) {
            logger.debug("Subscreen center coordinates wrong");
            return false;
        }
        return true;
    }

    (:test)
    function testRectangleProfile(logger as Test.Logger) as Boolean {
        var profile = new LayoutProfile(null, null);
        profile.applyConfiguration(246, 322, System.SCREEN_SHAPE_RECTANGLE, 24);

        if (profile.shape != :rectangle) {
            logger.debug("Shape mismatch: " + profile.shape);
            return false;
        }
        if (profile.hasSubscreen) {
            logger.debug("Expected hasSubscreen to be false");
            return false;
        }
        if (!profile.hasHeader) {
            logger.debug("Expected hasHeader to be true");
            return false;
        }
        if (profile.justification != Graphics.TEXT_JUSTIFY_LEFT) {
            logger.debug("Expected left justification on rectangle");
            return false;
        }
        if (profile.contentX != 12 || profile.contentWidth != (246 - 24)) {
            logger.debug("Content margins incorrect");
            return false;
        }
        if (profile.dividerY != (6 + 24 + 4)) {
            logger.debug("Divider Y incorrect on rectangle");
            return false;
        }
        return true;
    }

    (:test)
    function testRoundProfile(logger as Test.Logger) as Boolean {
        var profile = new LayoutProfile(null, null);
        profile.applyConfiguration(454, 454, System.SCREEN_SHAPE_ROUND, 24);

        if (profile.shape != :round) {
            logger.debug("Shape mismatch: " + profile.shape);
            return false;
        }
        if (profile.hasSubscreen) {
            logger.debug("Expected hasSubscreen false");
            return false;
        }
        if (profile.hasHeader) {
            logger.debug("Expected hasHeader false");
            return false;
        }
        if (profile.contentY != 0 || profile.contentHeight != 454) {
            logger.debug("Content geometry wrong for round");
            return false;
        }
        if (profile.tafJustification != Graphics.TEXT_JUSTIFY_CENTER) {
            logger.debug("Expected tafJustification to be TEXT_JUSTIFY_CENTER without VCENTER");
            return false;
        }
        return true;
    }

    (:test)
    function testInstinct40mmProfile(logger as Test.Logger) as Boolean {
        var profile = new LayoutProfile(null, null);
        profile.applyConfiguration(166, 166, System.SCREEN_SHAPE_SEMI_OCTAGON, 24);

        if (profile.shape != :semi_octagon) {
            logger.debug("Shape mismatch: " + profile.shape);
            return false;
        }
        if (profile.contentY != 58) {
            logger.debug("Expected contentY 58 on 40mm, got " + profile.contentY);
            return false;
        }
        if (profile.subscreenCenterX != 138 || profile.subscreenCenterY != 26) {
            logger.debug("Subscreen center coordinates wrong on 40mm");
            return false;
        }
        return true;
    }

    (:test)
    function testMockDataProviderVfr(logger as Test.Logger) as Boolean {
        var payload = MockDataProvider.getMockPayload("MOCK_VFR", "EGLL", false);
        if (payload == null || !payload.hasKey("raw")) {
            logger.debug("Payload missing raw key");
            return false;
        }
        if (!payload["flight_rules"].equals("VFR")) {
            logger.debug("Expected VFR flight rules");
            return false;
        }
        if (!payload["station"].equals("EGLL")) {
            logger.debug("Expected station EGLL");
            return false;
        }
        return true;
    }

    (:test)
    function testMockDataProviderIfrLong(logger as Test.Logger) as Boolean {
        var payload = MockDataProvider.getMockPayload("MOCK_IFR_LONG", "KJFK", false);
        if (!payload["flight_rules"].equals("LIFR")) {
            logger.debug("Expected LIFR flight rules");
            return false;
        }
        var raw = payload["raw"] as String;
        if (raw.find("SN FZFG") == null) {
            logger.debug("Expected snow and freezing fog in IFR raw string");
            return false;
        }
        return true;
    }

    (:test)
    function testMockDataProviderTaf(logger as Test.Logger) as Boolean {
        var payload = MockDataProvider.getMockPayload(null, "EGWU", true);
        var raw = payload["raw"] as String;
        if (raw.find("TAF EGWU") == null) {
            logger.debug("Expected TAF for EGWU");
            return false;
        }
        return true;
    }

    (:test)
    function testMockDataProviderAuthError(logger as Test.Logger) as Boolean {
        var payload = MockDataProvider.getMockPayload("MOCK_AUTH_ERROR", "EGLL", false);
        if (!payload.hasKey("status") || payload["status"] != 401) {
            logger.debug("Expected status 401");
            return false;
        }
        return true;
    }
}
