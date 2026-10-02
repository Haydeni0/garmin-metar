import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Lang;

class InactivityMenu2Delegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onWrap(key as WatchUi.Key) as Boolean {
        Application.getApp().resetTimer();
        return true;
    }

    function onNextPage() as Boolean {
        Application.getApp().resetTimer();
        return false;
    }

    function onPreviousPage() as Boolean {
        Application.getApp().resetTimer();
        return false;
    }

    function onTitle() as Void {
        Application.getApp().resetTimer();
    }

    function onFooter() as Void {
        Application.getApp().resetTimer();
    }

    function onBack() as Void {
        Application.getApp().resetTimer();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
