using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.System;
import Toybox.Lang;

class GarminMetarView extends WatchUi.View {

    hidden var mMetarCode = "Loading...";
    hidden var mToken; 
    hidden var mTextArea;

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        // Load the token from the secrets file
        if (Rez.Strings has :AvwxToken) {
            mToken = WatchUi.loadResource(Rez.Strings.AvwxToken);
        } else {
            mMetarCode = "Missing Token";
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

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        makeRequest();
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
        var url = "https://avwx.rest/api/metar/EGWU";
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
       }
       WatchUi.requestUpdate();
    }
}
