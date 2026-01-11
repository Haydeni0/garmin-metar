import Toybox.Lang;

module StationUtils {

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
