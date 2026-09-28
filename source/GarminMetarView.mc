using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.System;
using Toybox.Application;
import Toybox.Lang;

class GarminMetarView extends WatchUi.View {

    hidden var mMetarCode = "Loading...";
    hidden var mToken; 
    hidden var mTextAreaMetar;
    hidden var mTextAreaTaf;
    hidden var mCurrentLayoutArea as WatchUi.TextArea or Null = null;
    hidden var mStation = "EGWU";
    hidden var mIsShowingTaf = false;
    hidden var mScrollY = 0;
    hidden var mFlightRules = null;
    hidden var mProfile as LayoutProfile or Null = null;
    hidden var mNearbyService as NearbyAirportsService or Null = null;
    hidden var mIsLocatingClosest as Boolean = false;

    function initialize() {
        View.initialize();
        mToken = Application.Properties.getValue("AvwxToken");
        loadStationFromSettings();
    }

    hidden function loadStationFromSettings() as Void {
        var defaultStation = Application.Properties.getValue("TargetStation");
        if (defaultStation != null && defaultStation instanceof String && !defaultStation.equals("")) {
            mStation = defaultStation;
        } else {
            mStation = "";
        }
    }

    // Load your resources here
    function onLayout(dc) {
        mProfile = new LayoutProfile(dc, System.getDeviceSettings());

        // Load settings
        mToken = Application.Properties.getValue("AvwxToken");
        loadStationFromSettings();
        
        if (mToken == null || mToken.equals("YOUR_TOKEN_HERE") || mToken.equals("")) {
             mMetarCode = "Set Token in App Settings";
        } else if (mStation.equals("")) {
             mMetarCode = "Locating closest airport...";
        }

        mTextAreaMetar = new WatchUi.TextArea({
            :text => mMetarCode,
            :color => Graphics.COLOR_WHITE,
            :font => mProfile.font,
            :locX => mProfile.contentX,
            :locY => mProfile.contentY,
            :width => mProfile.contentWidth,
            :height => mProfile.contentHeight,
            :justification => mProfile.justification
        });

        mTextAreaTaf = new WatchUi.TextArea({
            :text => mMetarCode,
            :color => Graphics.COLOR_WHITE,
            :font => mProfile.font,
            :locX => mProfile.contentX,
            :locY => mProfile.tafBaseY,
            :width => mProfile.contentWidth,
            :height => 2000,
            :justification => mProfile.tafJustification
        });

        if (mIsShowingTaf) {
            mCurrentLayoutArea = mTextAreaTaf;
            setLayout([ mTextAreaTaf ]);
        } else {
            mCurrentLayoutArea = mTextAreaMetar;
            setLayout([ mTextAreaMetar ]);
        }
    }
    
    // Helper to refresh data when settings change
    function updateFromSettings() {
        mToken = Application.Properties.getValue("AvwxToken");
        loadStationFromSettings();
        makeRequest();
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        Application.getApp().resetTimer();
        makeRequest();
    }
    
    function setStation(station) {
        if (mIsLocatingClosest && mNearbyService != null) {
            mNearbyService.cancel();
            mIsLocatingClosest = false;
        }
        mStation = station;
        mFlightRules = null;
        mScrollY = 0;
        if (mIsShowingTaf) {
            mMetarCode = "Loading TAF: " + station + "...";
        } else {
            mMetarCode = "Loading METAR: " + station + "...";
        }
        WatchUi.requestUpdate();
    }

    function toggleTaf() {
        mIsShowingTaf = !mIsShowingTaf;
        mScrollY = 0;
        if (mIsShowingTaf) {
            if (mTextAreaTaf != null) {
                mCurrentLayoutArea = mTextAreaTaf;
                setLayout([ mTextAreaTaf ]);
            }
            if (mStation.equals("")) {
                mMetarCode = "Locating closest airport...";
            } else {
                mMetarCode = "Loading TAF: " + mStation + "...";
            }
        } else {
            if (mTextAreaMetar != null) {
                mCurrentLayoutArea = mTextAreaMetar;
                setLayout([ mTextAreaMetar ]);
            }
            if (mStation.equals("")) {
                mMetarCode = "Locating closest airport...";
            } else {
                mMetarCode = "Loading METAR: " + mStation + "...";
            }
        }
        WatchUi.requestUpdate();
        makeRequest();
    }

    function applyScrollDelta(deltaY as Float) {
        mScrollY += deltaY;
        if (mScrollY > 0) {
            mScrollY = 0;
        }
        WatchUi.requestUpdate();
    }

    function scroll(dir) {
        applyScrollDelta((dir * 40).toFloat());
    }

    // Update the view
    function onUpdate(dc) {
        if (mProfile != null && mTextAreaMetar != null && mTextAreaTaf != null) {
            if (mIsShowingTaf) {
                mTextAreaTaf.setText(mMetarCode);
                mTextAreaTaf.locY = mProfile.tafBaseY + mScrollY;
            } else {
                mTextAreaMetar.setText(mMetarCode);
                mTextAreaMetar.locY = mProfile.contentY + mScrollY;
            }
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        if (mProfile != null) {
            mProfile.drawHeader(dc, mStation, mFlightRules, mIsShowingTaf);
        }
    }

    function isShowingTaf() {
        return mIsShowingTaf;
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
        if (mNearbyService != null && mIsLocatingClosest) {
            mNearbyService.cancel();
            mIsLocatingClosest = false;
        }
    }

    function makeRequest() {
        if (mToken == null || mToken.equals("YOUR_TOKEN_HERE") || mToken.equals("")) {
             mMetarCode = "Set Token in App Settings";
             WatchUi.requestUpdate();
             return;
        }

        // If station is not set, automatically locate closest airport via GPS
        if (mStation == null || mStation.equals("")) {
            mFlightRules = null;
            mMetarCode = "Locating closest airport...";
            WatchUi.requestUpdate();
            locateClosestAirport();
            return;
        }

        // Mock data provider for offline testing and deterministic visual verification
        if (mToken.find("MOCK") == 0) {
            var mockData = MockDataProvider.getMockPayload(mToken, mStation, mIsShowingTaf);
            if (mockData.hasKey("status") && mockData["status"] != 200) {
                onReceive(mockData["status"], mockData);
            } else {
                onReceive(200, mockData);
            }
            return;
        }

        var url = "https://avwx.rest/api/metar/" + mStation;
        if (mIsShowingTaf) {
            url = "https://avwx.rest/api/taf/" + mStation;
        }
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
           if (data instanceof Dictionary) {
               if (data.hasKey("raw") && data["raw"] instanceof String) {
                   mMetarCode = data["raw"] as String;
               } else {
                   mMetarCode = "Bad Format";
               }
               if (data.hasKey("flight_rules") && data["flight_rules"] instanceof String) {
                   mFlightRules = data["flight_rules"] as String;
               } else {
                   mFlightRules = null;
               }
           } else {
               mMetarCode = "Bad Format";
           }
       } else {
           mFlightRules = null;
           mMetarCode = "Error: " + responseCode;
           if (responseCode == 401 || responseCode == 403) {
               mMetarCode += "\nCheck App Settings";
           }
       }
       WatchUi.requestUpdate();
    }

    function getMetarCode() as String {
        return mMetarCode;
    }

    function getFlightRules() as String or Null {
        return mFlightRules;
    }

    function getStation() as String {
        return mStation;
    }

    function getScrollY() as Number or Float {
        return mScrollY;
    }

    function setToken(token as String) as Void {
        mToken = token;
    }

    function locateClosestAirport() as Void {
        if (mIsLocatingClosest) {
            return;
        }
        if (mNearbyService == null) {
            mNearbyService = new NearbyAirportsService();
        }
        mIsLocatingClosest = true;
        mNearbyService.searchNearby(method(:onClosestAirportResult));
    }

    function getNearbyService() as NearbyAirportsService or Null {
        return mNearbyService;
    }

    function setNearbyServiceForTest(service as NearbyAirportsService) as Void {
        mNearbyService = service;
    }

    function getActiveTextArea() as WatchUi.TextArea or Null {
        return mCurrentLayoutArea;
    }

    function getTextAreaMetar() as WatchUi.TextArea or Null {
        return mTextAreaMetar;
    }

    function getTextAreaTaf() as WatchUi.TextArea or Null {
        return mTextAreaTaf;
    }

    function initTextAreasForTest() as Void {
        if (mProfile == null) {
            mProfile = new LayoutProfile(null, null);
        }
        mTextAreaMetar = new WatchUi.TextArea({
            :text => mMetarCode,
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_XTINY,
            :locX => 0,
            :locY => 0,
            :width => 100,
            :height => 100
        });
        mTextAreaTaf = new WatchUi.TextArea({
            :text => mMetarCode,
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_XTINY,
            :locX => 0,
            :locY => 0,
            :width => 100,
            :height => 100
        });
        mCurrentLayoutArea = mTextAreaMetar;
        setLayout([ mTextAreaMetar ]);
    }

    function onClosestAirportResult(success as Boolean, data as Object) as Void {
        mIsLocatingClosest = false;
        // If user already selected a station while search was in flight, do not override
        if (mStation != null && !mStation.equals("")) {
            return;
        }
        if (success && data instanceof Array && (data as Array).size() > 0) {
            var airports = data as Array<Dictionary>;
            var closest = airports[0];
            var icao = closest[:icao] as String;
            setStation(icao);
            makeRequest();
        } else {
            mStation = "";
            mFlightRules = null;
            mMetarCode = "No GPS Fix\nSelect Station";
            WatchUi.requestUpdate();
        }
    }

    function isLocatingClosest() as Boolean {
        return mIsLocatingClosest;
    }
}
