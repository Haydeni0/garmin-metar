using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.System;
using Toybox.Application;
import Toybox.Lang;

class GarminMetarView extends WatchUi.View {

    hidden var mMetarCode = "Loading...";
    hidden var mToken; 
    hidden var mTextArea;
    hidden var mStation = "EGWU";

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        // Load settings
        mToken = Application.Properties.getValue("AvwxToken");
        var defaultStation = Application.Properties.getValue("TargetStation");
        
        if (defaultStation != null && !defaultStation.equals("")) {
             // Only set mStation on startup or if specifically needed, 
             // but usually we want to respect the user's last selection or the default.
             // For now, let's respect the property if the memory is empty.
             if (mStation.equals("EGWU") && !defaultStation.equals("EGWU")) {
                 mStation = defaultStation;
                 mMetarCode = "Loading...";
             }
        }
        
        if (mToken == null || mToken.equals("YOUR_TOKEN_HERE") || mToken.equals("")) {
             mMetarCode = "Set Token in App Settings";
        }

        mTextArea = new WatchUi.TextArea({
            :text => mMetarCode,
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_XTINY,
            :locX => 0,
            :locY => 0,
            :width => dc.getWidth(),
            :height => dc.getHeight(),
            :justification => Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        });

        setLayout([ mTextArea ]);
    }
    
    // Helper to refresh data when settings change
    function updateFromSettings() {
        mToken = Application.Properties.getValue("AvwxToken");
        // We might want to update the station too if the user changed the default
        // But let's prioritize the token update for now
        makeRequest();
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        makeRequest();
    }
    
    function setStation(station) {
        mStation = station;
        mMetarCode = "Loading " + station + "...";
        if (mTextArea != null) {
            mTextArea.setText(mMetarCode);
        }
        WatchUi.requestUpdate();
    }

    // Update the view
    function onUpdate(dc) {
        if (mTextArea != null) {
            mTextArea.setText(mMetarCode);
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    function makeRequest() {
        if (mToken == null || mToken.equals("YOUR_TOKEN_HERE") || mToken.equals("")) {
             mMetarCode = "Set Token in App Settings";
             WatchUi.requestUpdate();
             return;
        }

        var url = "https://avwx.rest/api/metar/" + mStation;
        var params = {
            "token" => mToken,
            "format" => "json"
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Making Request to: " + url);
        // Note: In newer Monkey C SDKs, callback scope is handled automatically or via method()
        Communications.makeWebRequest(url, params, options, method(:onReceive));
    }

    // Fix: Add explicit types to match the makeWebRequest callback signature requirements
    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
       System.println("Response: " + responseCode);
       System.println("Data: " + data);
       
       if (responseCode == 200) {
           if (data instanceof Dictionary && data.hasKey("raw")) {
               mMetarCode = data["raw"];
           } else {
               mMetarCode = "Bad Format";
           }
       } else {
           mMetarCode = "Error: " + responseCode;
           if (responseCode == 401 || responseCode == 403) {
               mMetarCode += "\nCheck App Settings";
           }
       }
       WatchUi.requestUpdate();
    }
}
