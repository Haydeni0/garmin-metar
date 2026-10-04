using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Communications;
using Toybox.System;
using Toybox.Application;
using Toybox.Timer;
using Toybox.Time;
import Toybox.Lang;

class MetarWebRequestCallback {
    hidden var mView as GarminMetarView;
    hidden var mRequestId as Number;

    function initialize(view as GarminMetarView, requestId as Number) {
        mView = view;
        mRequestId = requestId;
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        mView.handleWebResponse(responseCode, data, mRequestId);
    }
}

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
    hidden var mNeedsRefresh as Boolean = true;
    hidden var mIsRequestInFlight as Boolean = false;
    hidden var mInFlightStation as String or Null = null;
    hidden var mInFlightIsTaf as Boolean = false;
    hidden var mRequestCount as Number = 0;
    hidden var mCurrentRequestId as Number = 0;
    hidden var mNoticeTimer as Timer.Timer or Null = null;
    hidden var mNoticeDismissed as Boolean = false;
    hidden var mActiveToken as String = "";
    hidden var mHasFallenBack as Boolean = false;
    hidden var mWeatherCache as Dictionary<String, Dictionary> = {};

    function initialize() {
        View.initialize();
        mToken = Application.Properties.getValue("AvwxToken");
        mActiveToken = StationUtils.getActiveToken(mToken);
        loadStationFromSettings();
    }

    hidden function loadStationFromSettings() as Void {
        var defaultStation = Application.Properties.getValue("TargetStation");
        if (defaultStation != null && defaultStation instanceof String && !defaultStation.equals("")) {
            mStation = defaultStation;
        } else {
            mStation = "";
        }

        if (mActiveToken == null || mActiveToken.equals("")) {
            mMetarCode = "Set Token in App Settings";
        } else if (mStation.equals("")) {
            mMetarCode = "Locating closest airport...";
        } else {
            mMetarCode = (mIsShowingTaf ? "Loading TAF: " : "Loading METAR: ") + mStation + "...";
        }
    }

    // Load your resources here
    function onLayout(dc) {
        mProfile = new LayoutProfile(dc, System.getDeviceSettings());

        // Load settings
        mToken = Application.Properties.getValue("AvwxToken");
        mActiveToken = StationUtils.getActiveToken(mToken);
        loadStationFromSettings();

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
        mActiveToken = StationUtils.getActiveToken(mToken);
        mHasFallenBack = false;
        mWeatherCache = {};
        loadStationFromSettings();
        mNeedsRefresh = true;
        makeRequest();
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        Application.getApp().resetTimer();
        mActiveToken = StationUtils.getActiveToken(mToken);
        if (!mNoticeDismissed && StationUtils.isPublicDefaultToken(mActiveToken)) {
            mMetarCode = "Using Public Token\nSet personal token in settings";
            mFlightRules = null;
            mNoticeTimer = new Timer.Timer();
            mNoticeTimer.start(method(:onNoticeTimeout), 2000, false);
            WatchUi.requestUpdate();
            return;
        }
        if (mStation == null || mStation.equals("")) {
            var target = Application.Properties.getValue("TargetStation");
            if (target == null || (target instanceof String && target.equals(""))) {
                locateClosestAirport();
                return;
            }
            mStation = target;
            mNeedsRefresh = true;
        }
        if (mNeedsRefresh) {
            makeRequest();
        }
    }

    function onNoticeTimeout() as Void {
        mNoticeDismissed = true;
        mNoticeTimer = null;
        if (mStation == null || mStation.equals("")) {
            var target = Application.Properties.getValue("TargetStation");
            if (target == null || (target instanceof String && target.equals(""))) {
                locateClosestAirport();
                return;
            }
            mStation = target;
        }
        makeRequest();
    }
    
    function setStation(station) {
        if (mIsLocatingClosest && mNearbyService != null) {
            mNearbyService.cancel();
            mIsLocatingClosest = false;
        }
        if (mStation != null && mStation.equals(station)) {
            var metarKey = station + ":METAR";
            var tafKey = station + ":TAF";
            if (mWeatherCache.hasKey(metarKey)) {
                mWeatherCache.remove(metarKey);
            }
            if (mWeatherCache.hasKey(tafKey)) {
                mWeatherCache.remove(tafKey);
            }
        }
        mStation = station;
        mNeedsRefresh = true;
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
        mNeedsRefresh = true;
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
        if (mNoticeTimer != null) {
            mNoticeTimer.stop();
            mNoticeTimer = null;
        }
        if (mNearbyService != null && mIsLocatingClosest) {
            mNearbyService.cancel();
            mIsLocatingClosest = false;
        }
    }



    function makeRequest() {
        if (mActiveToken == null || mActiveToken.equals("")) {
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

        var cacheKey = mStation + ":" + (mIsShowingTaf ? "TAF" : "METAR");
        if (mWeatherCache.hasKey(cacheKey)) {
            var entry = mWeatherCache[cacheKey] as Dictionary;
            if (entry != null && entry.hasKey(:timestamp) && ((Time.now().value() - (entry[:timestamp] as Number)) < StationUtils.CACHE_TTL_SECONDS)) {
                mMetarCode = entry[:code] as String;
                mFlightRules = entry[:flightRules] as String or Null;
                mIsRequestInFlight = false;
                mInFlightStation = null;
                mNeedsRefresh = false;
                if (mCurrentLayoutArea != null) {
                    mCurrentLayoutArea.setText(mMetarCode);
                }
                WatchUi.requestUpdate();
                return;
            }
        }

        if (mIsRequestInFlight && mInFlightStation != null && mInFlightStation.equals(mStation) && mInFlightIsTaf == mIsShowingTaf) {
            return;
        }

        mRequestCount++;
        mCurrentRequestId++;
        mIsRequestInFlight = true;
        mInFlightStation = mStation;
        mInFlightIsTaf = mIsShowingTaf;
        mNeedsRefresh = false;

        // Mock data provider for offline testing and deterministic visual verification
        if (mActiveToken.find("MOCK") == 0) {
            var mockData = MockDataProvider.getMockPayload(mActiveToken, mStation, mIsShowingTaf);
            var currentId = mCurrentRequestId;
            if (mockData.hasKey("status") && mockData["status"] != 200) {
                handleWebResponse(mockData["status"], mockData, currentId);
            } else {
                handleWebResponse(200, mockData, currentId);
            }
            return;
        }

        var url = "https://avwx.rest/api/metar/" + mStation;
        if (mIsShowingTaf) {
            url = "https://avwx.rest/api/taf/" + mStation;
        }
        var params = {
            "token" => mActiveToken,
            "format" => "json"
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Making Request to: " + url);
        var cb = new MetarWebRequestCallback(self, mCurrentRequestId);
        Communications.makeWebRequest(url, params, options, cb.method(:onReceive));
    }

    function handleWebResponse(responseCode as Number, data as Dictionary or String or Null, requestId as Number) as Void {
        if (requestId != mCurrentRequestId) {
            System.println("Discarding stale response for request: " + requestId + " (current is " + mCurrentRequestId + ")");
            return;
        }
        mIsRequestInFlight = false;
        mInFlightStation = null;
        onReceive(responseCode, data);
    }

    // Fix: Add explicit types to match the makeWebRequest callback signature requirements
    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
       mIsRequestInFlight = false;
       mInFlightStation = null;
       System.println("Response: " + responseCode);
       System.println("Data: " + data);
       
       if (responseCode == 200) {
           if (data instanceof Dictionary) {
               if (data.hasKey("raw") && data["raw"] instanceof String) {
                   mMetarCode = data["raw"] as String;
                   if (data.hasKey("flight_rules") && data["flight_rules"] instanceof String) {
                       mFlightRules = data["flight_rules"] as String;
                   } else {
                       mFlightRules = null;
                   }
                   if (mStation != null && !mStation.equals("")) {
                       var cacheKey = mStation + ":" + (mIsShowingTaf ? "TAF" : "METAR");
                       mWeatherCache[cacheKey] = {
                           :code => mMetarCode,
                           :flightRules => mFlightRules,
                           :timestamp => Time.now().value()
                       };
                   }
               } else {
                   mMetarCode = "Bad Format";
                   mFlightRules = null;
               }
           } else {
               mMetarCode = "Bad Format";
               mFlightRules = null;
           }
       } else if (responseCode == 401 && StationUtils.isConfiguredCustomToken(mActiveToken) && !mHasFallenBack) {
           mHasFallenBack = true;
           mActiveToken = StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN;
           if (!mNoticeDismissed) {
               mMetarCode = "Using Public Token\nSet personal token in settings";
               mFlightRules = null;
               mNoticeTimer = new Timer.Timer();
               mNoticeTimer.start(method(:onNoticeTimeout), 2000, false);
               WatchUi.requestUpdate();
               return;
           }
           makeRequest();
           return;
       } else {
           mFlightRules = null;
           var isPub = StationUtils.isPublicDefaultToken(mActiveToken);
           mMetarCode = StationUtils.formatErrorMessage(responseCode, isPub);
       }
       if (mCurrentLayoutArea != null) {
           mCurrentLayoutArea.setText(mMetarCode);
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

    function setToken(token as String or Null) as Void {
        mToken = token;
        mActiveToken = StationUtils.getActiveToken(token);
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

    function getNeedsRefreshForTest() as Boolean {
        return mNeedsRefresh;
    }

    function getIsRequestInFlightForTest() as Boolean {
        return mIsRequestInFlight;
    }

    function getRequestCountForTest() as Number {
        return mRequestCount;
    }

    function getCurrentRequestIdForTest() as Number {
        return mCurrentRequestId;
    }

    function triggerNoticeTimeoutForTest() as Void {
        onNoticeTimeout();
    }

    function getNoticeTimer() as Timer.Timer or Null {
        return mNoticeTimer;
    }

    function setTokenForTest(token as String or Null) as Void {
        setToken(token);
    }

    function getActiveTokenForTest() as String {
        return mActiveToken;
    }

    function getHasFallenBackForTest() as Boolean {
        return mHasFallenBack;
    }

    function setCacheEntryForTest(station as String, isTaf as Boolean, code as String, rules as String or Null, timestamp as Number) as Void {
        var cacheKey = station + ":" + (isTaf ? "TAF" : "METAR");
        mWeatherCache[cacheKey] = {
            :code => code,
            :flightRules => rules,
            :timestamp => timestamp
        };
    }

    function hasValidCacheEntry(station as String, isTaf as Boolean) as Boolean {
        var cacheKey = station + ":" + (isTaf ? "TAF" : "METAR");
        if (!mWeatherCache.hasKey(cacheKey)) {
            return false;
        }
        var entry = mWeatherCache[cacheKey] as Dictionary;
        if (entry == null || !entry.hasKey(:timestamp)) {
            return false;
        }
        return (Time.now().value() - (entry[:timestamp] as Number)) < StationUtils.CACHE_TTL_SECONDS;
    }
}
