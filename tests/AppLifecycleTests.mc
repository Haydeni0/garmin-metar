using Toybox.Test;
using Toybox.WatchUi;
using Toybox.Application;
import Toybox.Lang;

(:test)
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
        if (app.hasActiveTimer()) {
            logger.debug("Expected timer to be inactive after onStop");
            return false;
        }
        return true;
    }

    (:test)
    function testTimerDisabledWhenZero(logger as Test.Logger) as Boolean {
        var app = new GarminMetarApp();
        var orig = Application.Properties.getValue("AutoExitSeconds");
        Application.Properties.setValue("AutoExitSeconds", 0);
        app.resetTimer();

        var active = app.hasActiveTimer();
        Application.Properties.setValue("AutoExitSeconds", orig != null ? orig : 30);

        if (active) {
            logger.debug("Expected timer to be disabled when AutoExitSeconds is 0");
            return false;
        }
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

    (:test)
    function testInteractionResetsTimerOnKey(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);
        var app = Application.getApp() as GarminMetarApp;
        var countBefore = app.getTimerResetCount();

        delegate.handleKey(WatchUi.KEY_DOWN);
        if (app.getTimerResetCount() <= countBefore) {
            logger.debug("Expected handleKey to reset timer");
            return false;
        }
        return true;
    }

    (:test)
    function testInteractionResetsTimerOnTap(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);
        var app = Application.getApp() as GarminMetarApp;
        var countBefore = app.getTimerResetCount();

        delegate.handleTap();
        if (app.getTimerResetCount() <= countBefore) {
            logger.debug("Expected handleTap to reset timer");
            return false;
        }
        return true;
    }

    (:test)
    function testInteractionResetsTimerOnSwipe(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);
        var app = Application.getApp() as GarminMetarApp;
        var countBefore = app.getTimerResetCount();

        delegate.handleSwipe(WatchUi.SWIPE_LEFT);
        if (app.getTimerResetCount() <= countBefore) {
            logger.debug("Expected handleSwipe to reset timer");
            return false;
        }
        return true;
    }

    (:test)
    function testInteractionResetsTimerOnDrag(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);
        var app = Application.getApp() as GarminMetarApp;
        var countBefore = app.getTimerResetCount();

        delegate.handleDrag(WatchUi.DRAG_TYPE_START, [100, 100]);
        if (app.getTimerResetCount() <= countBefore) {
            logger.debug("Expected handleDrag to reset timer");
            return false;
        }
        return true;
    }

    (:test)
    function testInteractionResetsTimerOnSelect(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);
        var app = Application.getApp() as GarminMetarApp;
        var countBefore = app.getTimerResetCount();

        delegate.onSelect();
        if (app.getTimerResetCount() <= countBefore) {
            logger.debug("Expected onSelect to reset timer");
            return false;
        }
        return true;
    }
}

