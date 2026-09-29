using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;
import Toybox.Lang;

class GarminMetarApp extends Application.AppBase {

    hidden var mView;
    hidden var mTimer;
    hidden var mTimerResetCount as Number = 0;

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
            mTimer = null;
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
        mTimerResetCount++;
        var seconds = Application.Properties.getValue("AutoExitSeconds");
        if (seconds == null) { seconds = 30; }
        
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
        } else {
            mTimer = null;
        }
    }
    
    function stopTimer() as Void {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
    }

    function hasActiveTimer() as Boolean {
        return mTimer != null;
    }

    function getTimerResetCount() as Number {
        return mTimerResetCount;
    }

    function getView() {
        return mView;
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
