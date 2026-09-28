using Toybox.Test;
using Toybox.WatchUi;
import Toybox.Lang;

(:test)
module DelegateTests {

    (:test)
    function testSwipeLeftTogglesTaf(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        if (view.isShowingTaf()) {
            logger.debug("Expected initially not showing TAF");
            return false;
        }

        var handled = delegate.handleSwipe(WatchUi.SWIPE_LEFT);
        if (!handled || !view.isShowingTaf()) {
            logger.debug("Expected swipe left to handle and set isShowingTaf true");
            return false;
        }
        return true;
    }

    (:test)
    function testSwipeRightTogglesBackToMetar(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        delegate.handleSwipe(WatchUi.SWIPE_LEFT);
        if (!view.isShowingTaf()) {
            return false;
        }

        var handled = delegate.handleSwipe(WatchUi.SWIPE_RIGHT);
        if (!handled || view.isShowingTaf()) {
            logger.debug("Expected swipe right to return to METAR view");
            return false;
        }
        return true;
    }

    (:test)
    function testKeyScrollDownAndUp(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handledDown = delegate.handleKey(WatchUi.KEY_DOWN);
        if (!handledDown || view.getScrollY() != -40) {
            logger.debug("Expected scroll -40 after KEY_DOWN, got: " + view.getScrollY());
            return false;
        }

        var handledUp = delegate.handleKey(WatchUi.KEY_UP);
        if (!handledUp || view.getScrollY() != 0) {
            logger.debug("Expected scroll 0 after KEY_UP, got: " + view.getScrollY());
            return false;
        }
        return true;
    }

    (:test)
    function testScrollClampedAtTop(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        delegate.handleKey(WatchUi.KEY_UP);
        if (view.getScrollY() > 0) {
            logger.debug("Expected scroll <= 0, got: " + view.getScrollY());
            return false;
        }
        return true;
    }

    (:test)
    function testTouchDragIgnoredOnMetar(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var res = delegate.handleDrag(WatchUi.DRAG_TYPE_START, [100, 100]);
        if (res != false) {
            logger.debug("Expected onDrag to return false when viewing METAR");
            return false;
        }
        return true;
    }

    (:test)
    function testTouchDragAppliedOnTaf(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        view.toggleTaf();
        delegate.handleDrag(WatchUi.DRAG_TYPE_START, [100, 100]);
        var handled = delegate.handleDrag(WatchUi.DRAG_TYPE_CONTINUE, [100, 70]);

        if (!handled || view.getScrollY() != -30) {
            logger.debug("Expected drag scroll -30, got: " + view.getScrollY());
            return false;
        }
        return true;
    }

    (:test)
    function testStationChangeResetsScroll(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        delegate.handleKey(WatchUi.KEY_DOWN);
        if (view.getScrollY() != -40) {
            return false;
        }

        view.setStation("KJFK");
        if (!view.getStation().equals("KJFK") || view.getScrollY() != 0) {
            logger.debug("Expected station KJFK and scroll 0, got: " + view.getStation() + ", " + view.getScrollY());
            return false;
        }
        return true;
    }

    (:test)
    function testToggleTafResetsScroll(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        delegate.handleKey(WatchUi.KEY_DOWN);
        delegate.handleKey(WatchUi.KEY_DOWN);
        if (view.getScrollY() != -80) {
            return false;
        }

        view.toggleTaf();
        if (view.getScrollY() != 0) {
            logger.debug("Expected toggleTaf to reset scroll to 0, got: " + view.getScrollY());
            return false;
        }
        return true;
    }

    (:test)
    function testKeyEnterTogglesTaf(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        if (view.isShowingTaf()) {
            logger.debug("Expected initially not showing TAF");
            return false;
        }

        var handled = delegate.handleKey(WatchUi.KEY_ENTER);
        if (!handled || !view.isShowingTaf()) {
            logger.debug("Expected KEY_ENTER to toggle TAF to true");
            return false;
        }

        handled = delegate.handleKey(WatchUi.KEY_ENTER);
        if (!handled || view.isShowingTaf()) {
            logger.debug("Expected second KEY_ENTER to toggle back to METAR");
            return false;
        }
        return true;
    }

    (:test)
    function testOnSelectReturnsFalseForFallthrough(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handled = delegate.onSelect();
        if (handled) {
            logger.debug("Expected onSelect to return false to allow fallthrough to onKey/onTap");
            return false;
        }
        return true;
    }

    (:test)
    function testOnMenuOpensStationMenu(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handled = delegate.onMenu();
        if (!handled) {
            logger.debug("Expected onMenu to return true");
            return false;
        }
        return true;
    }

    (:test)
    function testTapOpensStationMenu(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handled = delegate.handleTap();
        if (!handled) {
            logger.debug("Expected handleTap to return true");
            return false;
        }
        return true;
    }

    (:test)
    function testOnSelectDoesNotToggleTaf(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var showingBefore = view.isShowingTaf();
        delegate.onSelect();
        if (view.isShowingTaf() != showingBefore) {
            logger.debug("onSelect must not toggle TAF (touch taps route to onSelect)");
            return false;
        }
        return true;
    }

    (:test)
    function testTapDoesNotToggleTaf(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var showingBefore = view.isShowingTaf();
        delegate.handleTap();
        if (view.isShowingTaf() != showingBefore) {
            logger.debug("handleTap must not toggle TAF");
            return false;
        }
        return true;
    }

    (:test)
    function testKeyMenuOpensStationMenu(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handled = delegate.handleKey(WatchUi.KEY_MENU);
        if (!handled) {
            logger.debug("Expected KEY_MENU to open station menu");
            return false;
        }
        return true;
    }

    (:test)
    function testSwipeUpAndDownScroll(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handledUp = delegate.handleSwipe(WatchUi.SWIPE_UP);
        if (!handledUp || view.getScrollY() != -40) {
            logger.debug("Expected scroll -40 after SWIPE_UP, got: " + view.getScrollY());
            return false;
        }

        var handledDown = delegate.handleSwipe(WatchUi.SWIPE_DOWN);
        if (!handledDown || view.getScrollY() != 0) {
            logger.debug("Expected scroll 0 after SWIPE_DOWN, got: " + view.getScrollY());
            return false;
        }
        return true;
    }

    (:test)
    function testUnhandledKeyReturnsFalse(logger as Test.Logger) as Boolean {
        var view = new GarminMetarView();
        var delegate = new GarminMetarDelegate(view);

        var handled = delegate.handleKey(WatchUi.KEY_ESC);
        if (handled) {
            logger.debug("Expected unhandled key KEY_ESC to return false for system back/exit");
            return false;
        }
        return true;
    }
}
