using Toybox.System;
using Toybox.Position;
using Toybox.Communications;
using Toybox.Application;
import Toybox.Lang;

class NearbyAirportsService {

    hidden var mCallback as (Method(success as Boolean, data as Object) as Void) or Null = null;
    hidden var mIsSearching as Boolean = false;

    function initialize() {
        mCallback = null;
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
        if (posInfo != null && posInfo.position != null) {
            onPositionAcquired(posInfo.position);
            return;
        }

        // Try one-shot position acquisition
        try {
            Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
        } catch (e) {
            notifyError("No GPS Fix");
        }
    }

    function onPosition(info as Position.Info) as Void {
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (e) {
            // Ignore failure disabling location events
        }

        if (info != null && info.position != null) {
            onPositionAcquired(info.position);
        } else {
            notifyError("No GPS Fix");
        }
    }

    function onPositionAcquired(position as Position.Location) as Void {
        var deg = position.toDegrees();
        var lat = deg[0];
        var lon = deg[1];
        fetchFromAvwx(lat, lon);
    }

    function fetchFromAvwx(lat as Float or Double, lon as Float or Double) as Void {
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

        Communications.makeWebRequest(url, params, options, method(:onReceiveNearby));
    }

    function onReceiveNearby(responseCode as Number, data as Dictionary or String or Null) as Void {
        mIsSearching = false;
        if (responseCode == 200 && data != null && data instanceof Array) {
            var rawArr = data as Array;
            var airports = parseNearbyResponse(rawArr);
            var cb = mCallback;
            if (airports.size() == 0) {
                notifyError("No Airports Found");
            } else if (cb != null) {
                cb.invoke(true, airports);
            }
        } else if (responseCode == 401) {
            notifyError("Auth Error 401");
        } else {
            notifyError("Network Error: " + responseCode);
        }
    }

    hidden function notifyError(message as String) as Void {
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

                if (entryDict.hasKey("distance")) {
                    dist = entryDict["distance"];
                }

                if (icao != null && icao instanceof String) {
                    var item = {
                        :icao => icao,
                        :name => name != null ? name : "",
                        :distance => dist != null ? dist : 0.0
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
