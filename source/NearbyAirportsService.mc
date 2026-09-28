using Toybox.System;
using Toybox.Position;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Timer;
import Toybox.Lang;

class NearbyAirportsService {

    hidden var mCallback as (Method(success as Boolean, data as Object) as Void) or Null = null;
    hidden var mIsSearching as Boolean = false;
    hidden var mGpsTimer as Timer.Timer or Null = null;

    function initialize() {
        mCallback = null;
        mGpsTimer = null;
    }

    function searchNearby(callback as Method(success as Boolean, data as Object) as Void) as Void {
        mCallback = callback;
        mIsSearching = true;

        var token = Application.Properties.getValue("AvwxToken");
        if (token != null && token instanceof String && token.find("MOCK") == 0) {
            var mockAirports = getMockNearbyAirports();
            var cb = mCallback;
            if (cb != null) {
                cb.invoke(true, mockAirports);
            }
            mIsSearching = false;
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

        var token = Application.Properties.getValue("AvwxToken");
        if (token == null || token.equals("") || token.equals("YOUR_TOKEN_HERE")) {
            notifyError("Token Missing");
            return;
        }

        var url = "https://avwx.rest/api/station/near/" + lat.format("%.4f") + "," + lon.format("%.4f");
        var params = {
            "token" => token,
            "format" => "json",
            "n" => 5
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Nearby Request to: " + url);
        Communications.makeWebRequest(url, params, options, method(:onReceiveNearby));
    }

    function onReceiveNearby(responseCode as Number, data as Dictionary or String or Null) as Void {
        mIsSearching = false;
        System.println("Nearby Response: " + responseCode);
        System.println("Nearby Data: " + data);
        if (responseCode == 200 && data != null && data instanceof Array) {
            var rawArr = data as Array;
            var airports = parseNearbyResponse(rawArr);
            var cb = mCallback;
            if (airports.size() == 0) {
                notifyError("No Airports Found");
            } else if (cb != null) {
                cb.invoke(true, airports);
            }
        } else if (responseCode == 401 || responseCode == 403) {
            notifyError("Auth Error " + responseCode);
        } else {
            notifyError("Network Error: " + responseCode);
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
        var latStr = coordStr.substring(0, commaIdx);
        var lonStr = coordStr.substring(commaIdx + 1, coordStr.length());
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
        if (cb != null) {
            cb.invoke(false, message);
        }
    }

    static function parseNearbyResponse(data as Array) as Array<Dictionary> {
        var result = [] as Array<Dictionary>;
        var maxCount = 5;
        if (data.size() < maxCount) {
            maxCount = data.size();
        }
        for (var i = 0; i < maxCount; i++) {
            var entry = data[i];
            if (entry instanceof Dictionary) {
                var entryDict = entry as Dictionary;
                var icao = null;
                var name = null;
                var dist = null;

                if (entryDict.hasKey("station") && entryDict["station"] instanceof Dictionary) {
                    var st = entryDict["station"] as Dictionary;
                    if (st.hasKey("icao")) {
                        icao = st["icao"];
                    }
                    if (st.hasKey("name")) {
                        name = st["name"];
                    }
                } else if (entryDict.hasKey("icao")) {
                    icao = entryDict["icao"];
                    if (entryDict.hasKey("name")) {
                        name = entryDict["name"];
                    }
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

                if (dist != null && dist instanceof String) {
                    dist = (dist as String).toFloat();
                }

                if (icao != null && icao instanceof String) {
                    var item = {
                        :icao => icao,
                        :name => name != null ? name : "",
                        :distance => dist
                    };
                    result.add(item);
                }
            }
        }
        return result;
    }

    static function getMockNearbyAirports() as Array<Dictionary> {
        return [
            {:icao => "EGLL", :name => "Heathrow", :distance => 4.2},
            {:icao => "EGWU", :name => "Northolt", :distance => 6.1},
            {:icao => "EGUB", :name => "Benson", :distance => 18.5},
            {:icao => "EGVO", :name => "Odiham", :distance => 24.0},
            {:icao => "EGLC", :name => "London City", :distance => 26.8}
        ];
    }
}
