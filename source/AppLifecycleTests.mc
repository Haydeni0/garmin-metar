using Toybox.Test;
import Toybox.Lang;

module AppLifecycleTests {

    (:test)
    function testTimerStartsByDefault(logger as Test.Logger) as Boolean {
        var app = new GarminMetarApp();
        app.resetTimer();

        if (!app.hasActiveTimer()) {
            logger.debug("Expected timer to be active after resetTimer");
            return false;
        }
        return true;
    }

    (:test)
    function testTimerStopOnAppStop(logger as Test.Logger) as Boolean {
        var app = new GarminMetarApp();
        app.resetTimer();
        app.onStop(null);
        // Verification: ensure no unhandled exception or crash on stop
        return true;
    }

    (:test)
    function testInitialViewContract(logger as Test.Logger) as Boolean {
        var app = new GarminMetarApp();
        var initial = app.getInitialView();

        if (initial == null || !(initial instanceof Array) || initial.size() != 2) {
            logger.debug("Expected initial view array of size 2");
            return false;
        }

        if (!(initial[0] instanceof GarminMetarView)) {
            logger.debug("Expected initial[0] to be GarminMetarView");
            return false;
        }

        if (!(initial[1] instanceof GarminMetarDelegate)) {
            logger.debug("Expected initial[1] to be GarminMetarDelegate");
            return false;
        }

        return true;
    }

    (:test)
    function testSettingsChangedRefreshesTimer(logger as Test.Logger) as Boolean {
        var app = new GarminMetarApp();
        app.getInitialView();
        app.onSettingsChanged();

        if (!app.hasActiveTimer()) {
            logger.debug("Expected active timer after settings change");
            return false;
        }
        return true;
    }
}
