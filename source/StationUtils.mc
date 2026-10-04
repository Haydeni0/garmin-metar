import Toybox.Lang;

module StationUtils {

    const DEFAULT_PUBLIC_AVWX_TOKEN = "rU8FKBV59pPWo0Vlmk_IDFKe_qmhoUV2DqPi6qxJaAw";
    const CACHE_TTL_SECONDS = 300;

    function getActiveToken(configuredToken as String or Null) as String {
        if (configuredToken == null || configuredToken.equals("") || configuredToken.equals("YOUR_TOKEN_HERE")) {
            return DEFAULT_PUBLIC_AVWX_TOKEN;
        }
        return configuredToken;
    }

    function isPublicDefaultToken(token as String or Null) as Boolean {
        if (token == null || token.equals("") || token.equals("YOUR_TOKEN_HERE") || token.equals(DEFAULT_PUBLIC_AVWX_TOKEN)) {
            return true;
        }
        return false;
    }

    function isConfiguredCustomToken(token as String or Null) as Boolean {
        return !isPublicDefaultToken(token);
    }

    function absVal(val as Float or Double) as Float or Double {
        return val < 0 ? -val : val;
    }

    function formatErrorMessage(responseCode as Number, isPublicToken as Boolean) as String {
        if (responseCode == -104) {
            return "Phone Disconnected\nCheck Bluetooth";
        } else if (responseCode == -2) {
            return "Phone Timeout\nOpen Garmin Connect";
        } else if (responseCode == -3 || responseCode == -300) {
            return "Network Timeout\nCheck Phone Internet";
        } else if (responseCode == -101) {
            return "Bluetooth Busy\nTry Again";
        } else if (responseCode == -400) {
            return "Response Too Large";
        } else if (responseCode < 0) {
            return "Connection Error (" + responseCode + ")";
        } else if (responseCode == 400) {
            return "Invalid Request (400)";
        } else if (responseCode == 401) {
            return "Token Invalid (401)\nCheck App Settings";
        } else if (responseCode == 403 || responseCode == 429) {
            if (isPublicToken) {
                return "Public Limit Reached\nEnter Own Token in Settings";
            } else {
                return "Rate Limited (" + responseCode + ")\nWait or Check Token";
            }
        } else if (responseCode == 404) {
            return "Station Not Found\nVerify ICAO Code (404)";
        } else if (responseCode == 500 || responseCode == 502 || responseCode == 503 || responseCode == 504) {
            return "Server Error (" + responseCode + ")\nTry Again Later";
        }
        return "Error: " + responseCode;
    }

    function formatNearbyErrorMessage(responseCode as Number, isPublicToken as Boolean) as String {
        if (responseCode == -104) {
            return "Phone Disconnected";
        } else if (responseCode == -2 || responseCode == -3 || responseCode == -300) {
            return "Network Timeout";
        } else if (responseCode == 401) {
            return "Token Invalid";
        } else if (responseCode == 403 || responseCode == 429) {
            return "Limit Reached";
        }
        return "Error: " + responseCode;
    }

    function getStations(listStr as String or Null) as Array<String> {
        var stations = [] as Array<String>;
        if (listStr == null || !(listStr instanceof String)) {
            return stations;
        }

        return parseStationString(listStr as String);
    }

    function parseStationString(listStr as String) as Array<String> {
        var stations = [] as Array<String>;
        
        // listStr is typed as String, so it's not null here in this context
        // if (listStr == null) return stations;
        
        // Simpler approach: build array from comma separation
        var currentStart = 0;
        var commaIndex = listStr.find(",");
        
        while (commaIndex != null) {
            var code = listStr.substring(currentStart, commaIndex + currentStart);
            if (code != null) {
                // Manual trim
                code = trim(code);
                if (code.length() > 0) {
                    stations.add(code);
                }
            }
            
            currentStart = currentStart + commaIndex + 1; // skip comma
            if (currentStart >= listStr.length()) { break; }
            var sub = listStr.substring(currentStart, listStr.length());
            commaIndex = sub.find(",");
        }
        
        // Add last item
        if (currentStart < listStr.length()) {
            var code = listStr.substring(currentStart, listStr.length());
             if (code != null) {
                code = trim(code);
                if (code.length() > 0) {
                    stations.add(code);
                }
            }
        }
        
        return stations;
    }
    
    // Helper to trim spaces
    function trim(str as String) as String {
        if (str.length() == 0) { return str; }
        
        var start = 0;
        var end = str.length();
        
        // Trim start
        while (start < end && str.substring(start, start+1).equals(" ")) {
            start++;
        }
        
        // Trim end
        while (end > start && str.substring(end-1, end).equals(" ")) {
            end--;
        }
        
        if (start > 0 || end < str.length()) {
            return str.substring(start, end);
        }
        
        return str;
    }
}
