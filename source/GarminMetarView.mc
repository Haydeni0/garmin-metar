using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.System;
import Toybox.Lang;

class GarminMetarView extends WatchUi.View {

    hidden var mMetarCode = "Loading...";
    hidden var mToken; 

    function initialize() {
        View.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
        // Load the token from the secrets file
        if (Rez.Strings has :AvwxToken) {
            mToken = WatchUi.loadResource(Rez.Strings.AvwxToken);
        } else {
            mMetarCode = "Missing Token";
        }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        makeRequest();
    }

    // Update the view
    function onUpdate(dc) {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        var view = View.findDrawableById("MetarLabel");
        // Fix: Explicitly check/cast to Text to satisfy the type checker
        if (view instanceof WatchUi.Text) {
            view.setText(mMetarCode);
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    function makeRequest() {
        var url = "https://avwx.rest/api/metar/KJFK";
        var params = {
            "token" => mToken,
            "format" => "json"
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Note: In newer Monkey C SDKs, callback scope is handled automatically or via method()
        Communications.makeWebRequest(url, params, options, method(:onReceive));
    }

    // Fix: Add explicit types to match the makeWebRequest callback signature requirements
    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
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
