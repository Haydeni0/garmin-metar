using Toybox.System;
using Toybox.Position;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Timer;
using Toybox.Time;
import Toybox.Lang;

class NearbyAirportsService {

    hidden static var sCachedAirports as Array<Dictionary> or Null = null;
    hidden static var sCachedLat as Float or Double or Null = null;
    hidden static var sCachedLon as Float or Double or Null = null;
    hidden static var sCachedTimestamp as Number or Null = null;

    hidden var mCallback as (Method(success as Boolean, data as Object) as Void) or Null = null;
    hidden var mIsSearching as Boolean = false;
    hidden var mGpsTimer as Timer.Timer or Null = null;
    hidden var mActiveToken as String = "";
    hidden var mInFlightLat as Float or Double or Null = null;
    hidden var mInFlightLon as Float or Double or Null = null;
    hidden var mHasFallenBack as Boolean = false;

    function initialize() {
        mCallback = null;
        mGpsTimer = null;
        mActiveToken = "";
        mInFlightLat = null;
        mInFlightLon = null;
        mHasFallenBack = false;
    }

    function searchNearby(callback as Method(success as Boolean, data as Object) as Void) as Void {
        mCallback = callback;
        mIsSearching = true;

        var token = Application.Properties.getValue("AvwxToken");
        mActiveToken = StationUtils.getActiveToken(token);
        mHasFallenBack = false;

        if (token != null && token instanceof String && token.find("MOCK") == 0) {
            var mockAirports = getMockNearbyAirports();
            var cb = mCallback;
            mCallback = null;
            mIsSearching = false;
            if (cb != null) {
                cb.invoke(true, mockAirports);
            }
            return;
        }

        // Check if Positioning is available on device
        if (!(Toybox has :Position)) {
            notifyError("No GPS Available");
            return;
        }

        var posInfo = Position.getInfo();
        if (isValidLocation(posInfo)) {
            onPositionAcquired(posInfo.position);
            return;
        }

        // Check for simulated GPS property (configured via .env for simulator debugging)
        var simGps = Application.Properties.getValue("SimulatedGps");
        if (simGps != null && simGps instanceof String && !simGps.equals("")) {
            var coords = parseCoordinates(simGps as String);
            if (coords != null && isValidCoordinate(coords[0], coords[1])) {
                fetchFromAvwx(coords[0], coords[1]);
                return;
            }
        }

        startGpsListening();
    }

    hidden function startGpsListening() as Void {
        stopGpsListening();
        mGpsTimer = new Timer.Timer();
        mGpsTimer.start(method(:onGpsTimeout), 8000, false);

        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        } catch (e) {
            stopGpsListening();
            notifyError("No GPS Fix");
        }
    }

    hidden function stopGpsListening() as Void {
        if (mGpsTimer != null) {
            mGpsTimer.stop();
            mGpsTimer = null;
        }
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (e) {
            // Ignore error disabling location events
        }
    }

    function cancel() as Void {
        stopGpsListening();
        mIsSearching = false;
        mCallback = null;
    }

    function isSearching() as Boolean {
        return mIsSearching;
    }

    function onGpsTimeout() as Void {
        stopGpsListening();
        notifyError("No GPS Fix");
    }

    function onPosition(info as Position.Info) as Void {
        if (isValidLocation(info)) {
            stopGpsListening();
            onPositionAcquired(info.position);
        }
    }

    function onPositionAcquired(position as Position.Location) as Void {
        var deg = position.toDegrees();
        var lat = deg[0];
        var lon = deg[1];
        fetchFromAvwx(lat, lon);
    }

    function fetchFromAvwx(lat as Float or Double, lon as Float or Double) as Void {
        if (!isValidCoordinate(lat, lon)) {
            notifyError("No GPS Fix");
            return;
        }

        if (!mHasFallenBack) {
            var token = Application.Properties.getValue("AvwxToken");
            mActiveToken = StationUtils.getActiveToken(token);
        }

        mInFlightLat = lat;
        mInFlightLon = lon;

        if (sCachedAirports != null && sCachedLat != null && sCachedLon != null && sCachedTimestamp != null) {
            var age = Time.now().value() - sCachedTimestamp;
            if (age < StationUtils.CACHE_TTL_SECONDS) {
                var dLat = StationUtils.absVal(lat - sCachedLat);
                var dLon = StationUtils.absVal(lon - sCachedLon);
                if (dLat < 0.045 && dLon < 0.045) {
                    stopGpsListening();
                    mIsSearching = false;
                    var cb = mCallback;
                    mCallback = null;
                    if (cb != null) {
                        cb.invoke(true, sCachedAirports);
                    }
                    return;
                }
            }
        }

        var limit = getNearbyLimit();
        var url = "https://avwx.rest/api/station/near/" + lat.format("%.4f") + "," + lon.format("%.4f");
        var params = {
            "token" => mActiveToken,
            "format" => "json",
            "n" => limit
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        mIsSearching = true;
        System.println("Nearby Request to: " + url);
        Communications.makeWebRequest(url, params, options, method(:onReceiveNearby));
    }

    function onReceiveNearby(responseCode as Number, data as Dictionary or String or Null) as Void {
        System.println("Nearby Response: " + responseCode);
        System.println("Nearby Data: " + data);
        if (responseCode == 200 && data != null && data instanceof Array) {
            var rawArr = data as Array;
            var airports = parseNearbyResponse(rawArr);
            if (airports.size() == 0) {
                notifyError("No Airports Found");
                return;
            }
            sCachedAirports = airports;
            sCachedLat = mInFlightLat;
            sCachedLon = mInFlightLon;
            sCachedTimestamp = Time.now().value();

            mIsSearching = false;
            var cb = mCallback;
            mCallback = null;
            if (cb != null) {
                cb.invoke(true, airports);
            }
            return;
        } else if (responseCode == 200) {
            notifyError("Bad Format");
        } else if (responseCode == 401 && !mHasFallenBack && StationUtils.isConfiguredCustomToken(mActiveToken) && mInFlightLat != null && mInFlightLon != null) {
            mHasFallenBack = true;
            mActiveToken = StationUtils.DEFAULT_PUBLIC_AVWX_TOKEN;
            fetchFromAvwx(mInFlightLat, mInFlightLon);
            return;
        } else {
            var isPub = StationUtils.isPublicDefaultToken(mActiveToken);
            notifyError(StationUtils.formatNearbyErrorMessage(responseCode, isPub));
        }
    }

    static function isValidCoordinate(lat as Float or Double, lon as Float or Double) as Boolean {
        if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) {
            return false;
        }
        // Garmin sentinel for uninitialized GPS coordinates is [180.0, 180.0]
        if (lat == 180.0 && lon == 180.0) {
            return false;
        }
        return true;
    }

    static function isValidLocation(info as Position.Info or Null) as Boolean {
        if (info == null || info.position == null) {
            return false;
        }
        var deg = info.position.toDegrees();
        return isValidCoordinate(deg[0], deg[1]);
    }

    static function parseCoordinates(coordStr as String) as Array<Float> or Null {
        var commaIdx = coordStr.find(",");
        if (commaIdx == null || commaIdx <= 0) {
            return null;
        }
        var latStr = StationUtils.trim(coordStr.substring(0, commaIdx));
        var lonStr = StationUtils.trim(coordStr.substring(commaIdx + 1, coordStr.length()));
        if (latStr == null || lonStr == null) {
            return null;
        }
        var lat = latStr.toFloat();
        var lon = lonStr.toFloat();
        if (lat == null || lon == null) {
            return null;
        }
        return [lat, lon] as Array<Float>;
    }

    hidden function notifyError(message as String) as Void {
        stopGpsListening();
        mIsSearching = false;
        var cb = mCallback;
        mCallback = null;
        if (cb != null) {
            cb.invoke(false, message);
        }
    }

    function getCallbackForTest() as Method or Null {
        return mCallback;
    }

    function setCallbackForTest(cb as Method) as Void {
        mCallback = cb;
    }

    static function clearStaticCacheForTest() as Void {
        sCachedAirports = null;
        sCachedLat = null;
        sCachedLon = null;
        sCachedTimestamp = null;
    }

    function getActiveTokenForTest() as String {
        return mActiveToken;
    }

    function getHasFallenBackForTest() as Boolean {
        return mHasFallenBack;
    }

    static function getNearbyLimit() as Number {
        try {
            var count = Application.Properties.getValue("NearbyCount");
            if (count != null && count instanceof Number && count > 0) {
                return count as Number;
            }
        } catch (e) {
        }
        return 5;
    }

    hidden static function parseAirportEntry(entryDict as Dictionary) as Dictionary or Null {
        var icao = null;
        var name = null;
        var dist = null;

        if (entryDict.hasKey("station") && entryDict["station"] instanceof Dictionary) {
            var st = entryDict["station"] as Dictionary;
            if (st.hasKey("icao") && st["icao"] instanceof String) {
                icao = st["icao"];
            }
            if (st.hasKey("name") && st["name"] instanceof String) {
                name = st["name"];
            }
        } else if (entryDict.hasKey("icao") && entryDict["icao"] instanceof String) {
            icao = entryDict["icao"];
            if (entryDict.hasKey("name") && entryDict["name"] instanceof String) {
                name = entryDict["name"];
            }
        }

        if (icao == null) {
            return null;
        }

        if (entryDict.hasKey("nautical_miles")) {
            dist = entryDict["nautical_miles"];
        } else if (entryDict.hasKey("distance")) {
            dist = entryDict["distance"];
        } else if (entryDict.hasKey("miles")) {
            dist = entryDict["miles"];
        } else if (entryDict.hasKey("station") && entryDict["station"] instanceof Dictionary) {
            var stDict = entryDict["station"] as Dictionary;
            if (stDict.hasKey("nautical_miles")) {
                dist = stDict["nautical_miles"];
            } else if (stDict.hasKey("distance")) {
                dist = stDict["distance"];
            }
        }

        if (dist != null) {
            if (dist instanceof Number || dist instanceof Long) {
                dist = dist.toFloat();
            } else if (dist instanceof String) {
                dist = (dist as String).toFloat();
            }
        }

        return {
            :icao => icao,
            :name => name != null ? name : "",
            :distance => dist
        };
    }

    static function parseNearbyResponse(data as Array) as Array<Dictionary> {
        var result = [] as Array<Dictionary>;
        var maxCount = getNearbyLimit();
        for (var i = 0; i < data.size() && result.size() < maxCount; i++) {
            var entry = data[i];
            if (entry instanceof Dictionary) {
                var item = parseAirportEntry(entry as Dictionary);
                if (item != null) {
                    result.add(item);
                }
            }
        }
        return result;
    }

    static function getMockNearbyAirports() as Array<Dictionary> {
        var allMocks = MockDataProvider.getMockNearbyAirports();
        var limit = getNearbyLimit();
        if (allMocks.size() <= limit) {
            return allMocks;
        }
        var sliced = [] as Array<Dictionary>;
        for (var i = 0; i < limit; i++) {
            sliced.add(allMocks[i]);
        }
        return sliced;
    }
}
