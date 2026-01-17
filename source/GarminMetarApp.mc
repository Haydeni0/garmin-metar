using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

class GarminMetarApp extends Application.AppBase {

    hidden var mView;
    hidden var mTimer;
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        resetTimer();
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        if (mTimer != null) {
            mTimer.stop();
        }
    }

    // New: Handle settings changes from the phone
    function onSettingsChanged() {
        resetTimer(); 
        if (mView != null) {
            mView.updateFromSettings();
        }
        WatchUi.requestUpdate();
    }
    
    function resetTimer() {
        var seconds = Application.Properties.getValue("AutoExitSeconds");
        if (seconds == null) { seconds = 60; }
        
        // Always stop the current timer if it exists
        if (mTimer != null) {
            mTimer.stop();
        }
        
        // If seconds is 0, we treated it as "Unlimited", so don't start the timer.
        if (seconds > 0) {
            if (mTimer == null) {
                mTimer = new Timer.Timer();
            }
            mTimer.start(method(:onTimerTimeout), seconds * 1000, false);
        }
    }
    
    function onTimerTimeout() as Void {
        System.exit();
    }

    // Return the initial view of your application here
    function getInitialView() {
        mView = new GarminMetarView();
        var delegate = new GarminMetarDelegate(mView);
        return [ mView, delegate ];
    }
}
