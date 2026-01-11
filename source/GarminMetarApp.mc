using Toybox.Application;
using Toybox.WatchUi;

class GarminMetarApp extends Application.AppBase {

    hidden var mView;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // New: Handle settings changes from the phone
    function onSettingsChanged() {
        if (mView != null) {
            mView.updateFromSettings();
        }
        WatchUi.requestUpdate();
    }

    // Return the initial view of your application here
    function getInitialView() {
        mView = new GarminMetarView();
        var delegate = new GarminMetarDelegate(mView);
        return [ mView, delegate ];
    }
}
