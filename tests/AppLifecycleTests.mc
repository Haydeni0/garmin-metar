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

    (:test)
    function testMenuRetainsActiveInactivityTimer(logger as Test.Logger) as Boolean {
        var app = Application.getApp() as GarminMetarApp;
        app.resetTimer();

        if (!app.hasActiveTimer()) {
            logger.debug("Expected active timer before menu push");
            return false;
        }

        var view = new GarminMetarView();
        view.onHide();

        if (!app.hasActiveTimer()) {
            logger.debug("Expected timer to remain active when view is hidden by menu");
            return false;
        }

        view.onShow();

        if (!app.hasActiveTimer()) {
            logger.debug("Expected timer to remain active when view is restored from menu");
            return false;
        }

        return true;
    }

    (:test)
    function testStationMenuOpeningResetsTimer(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);
        var app = Application.getApp() as GarminMetarApp;
        var countBefore = app.getTimerResetCount();

        delegate.pushStationMenu();
        if (app.getTimerResetCount() <= countBefore) {
            logger.debug("Expected pushStationMenu to reset timer");
            return false;
        }
        return true;
    }

    (:test)
    function testStationMenuNavigationResetsTimer(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new StationMenuDelegate(view);
        var app = Application.getApp() as GarminMetarApp;

        var count = app.getTimerResetCount();
        delegate.onWrap(WatchUi.KEY_DOWN);
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected onWrap to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onNextPage();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected onNextPage to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onPreviousPage();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected onPreviousPage to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onTitle();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected onTitle to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onFooter();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected onFooter to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onBack();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected onBack to reset timer");
            return false;
        }

        return true;
    }

    (:test)
    function testNearbyMenuNavigationResetsTimer(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var menu = new WatchUi.Menu2({:title=>"Nearby"});
        var delegate = new NearbyMenuDelegate(view, menu);
        var app = Application.getApp() as GarminMetarApp;

        var count = app.getTimerResetCount();
        delegate.onWrap(WatchUi.KEY_DOWN);
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected NearbyMenuDelegate onWrap to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onNextPage();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected NearbyMenuDelegate onNextPage to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onPreviousPage();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected NearbyMenuDelegate onPreviousPage to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onTitle();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected NearbyMenuDelegate onTitle to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onFooter();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected NearbyMenuDelegate onFooter to reset timer");
            return false;
        }

        count = app.getTimerResetCount();
        delegate.onBack();
        if (app.getTimerResetCount() <= count) {
            logger.debug("Expected NearbyMenuDelegate onBack to reset timer");
            return false;
        }

        return true;
    }

    (:test)
    function testInactivityMenu2DelegateInheritance(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var menu = new WatchUi.Menu2({:title => "Test"});
        var stationDelegate = new StationMenuDelegate(view);
        var nearbyDelegate = new NearbyMenuDelegate(view, menu);

        if (!(stationDelegate instanceof InactivityMenu2Delegate)) {
            logger.debug("Expected StationMenuDelegate to inherit from InactivityMenu2Delegate");
            return false;
        }
        if (!(nearbyDelegate instanceof InactivityMenu2Delegate)) {
            logger.debug("Expected NearbyMenuDelegate to inherit from InactivityMenu2Delegate");
            return false;
        }

        var app = Application.getApp() as GarminMetarApp;
        app.resetTimer();
        var resetsBefore = app.getTimerResetCount();

        var wrapHandled = stationDelegate.onWrap(WatchUi.KEY_DOWN);
        if (!wrapHandled) {
            logger.debug("Expected onWrap to return true");
            return false;
        }
        if (app.getTimerResetCount() <= resetsBefore) {
            logger.debug("Expected timer reset count to increment after onWrap");
            return false;
        }

        return true;
    }
}



