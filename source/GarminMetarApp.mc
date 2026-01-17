using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

class GarminMetarApp extends Application.AppBase {

    hidden var mView;
    hidden var mTimer;
    const TIMEOUT_MS = 60000; // 60 seconds

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
        startTimer();
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        if (mTimer != null) {
            mTimer.stop();
        }
    }

    // New: Handle settings changes from the phone
    function onSettingsChanged() {
        resetTimer(); // User interaction via phone counts as activity? Maybe. Safe to reset.
        if (mView != null) {
            mView.updateFromSettings();
        }
        WatchUi.requestUpdate();
    }
    
    function startTimer() {
        mTimer = new Timer.Timer();
        mTimer.start(method(:onTimerTimeout), TIMEOUT_MS, false); // false = one-shot
    }
    
    function resetTimer() {
        if (mTimer != null) {
            mTimer.stop();
            mTimer.start(method(:onTimerTimeout), TIMEOUT_MS, false);
        } else {
            startTimer();
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
