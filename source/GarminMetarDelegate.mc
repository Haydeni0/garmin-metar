using Toybox.WatchUi;
using Toybox.Application;
import Toybox.Lang;

class GarminMetarDelegate extends WatchUi.BehaviorDelegate {

    hidden var mView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onMenu() {
        return true;
    }
    
    function onSelect() {
        var menu = new WatchUi.Menu2({:title=>"Select Station"});
        
        var listStr = Application.Properties.getValue("StationList");
        var stations = [];
        
        if (listStr != null && listStr instanceof String) {
            // Manual split since String.split isn't always reliable in standard libs or we want explicit control
            // Actually, Monkey C String doesn't have .split() until newer API levels. 
            // We'll write a simple parser or assume the user inputs clean data, 
            // but let's try to find commas.
            
            // Simpler approach: build array from comma separation
            var currentStart = 0;
            var commaIndex = listStr.find(",");
            
            while (commaIndex != null) {
                var code = listStr.substring(currentStart, commaIndex + currentStart);
                // Trim logic usually needed, but standard library check...
                // Only String.substring exists. No trim(). 
                // We will assume the user might verify no spaces or we just strip them if we could.
                // For now, let's just create items.
                if (code != null) {
                    stations.add(code);
                }
                
                currentStart = currentStart + commaIndex + 1; // skip comma
                if (currentStart >= listStr.length()) { break; }
                var sub = listStr.substring(currentStart, listStr.length());
                commaIndex = sub.find(",");
            }
            // Add last item
            if (currentStart < listStr.length()) {
                stations.add(listStr.substring(currentStart, listStr.length()));
            }
        }
        
        // Trim spaces manually from our list (simple space removal)
        // Monkey C generic helper for string trimming if available? No.
        // We will just add them as is, but we could improve this later.
        
        // Cast for safety
        var safeStations = stations as Array<String>;

        // Sort stations alphabetically
        for (var i = 0; i < safeStations.size(); i++) {
            for (var j = i + 1; j < safeStations.size(); j++) {
                if (safeStations[i].compareTo(safeStations[j]) > 0) {
                    var temp = safeStations[i];
                    safeStations[i] = safeStations[j];
                    safeStations[j] = temp;
                }
            }
        }
        
        for (var i = 0; i < safeStations.size(); i++) {
            var code = safeStations[i];
            // Simple trim of leading space if it exists (one level)
            if (code.length() > 0 && code.substring(0,1).equals(" ")) {
                code = code.substring(1, code.length());
            }
            if (code.length() > 0 && code.substring(code.length()-1, code.length()).equals(" ")) {
                 code = code.substring(0, code.length()-1);
            }
            
            menu.addItem(new WatchUi.MenuItem(code, null, code, null));
        }
        
        WatchUi.pushView(menu, new StationMenuDelegate(mView), WatchUi.SLIDE_UP);
        return true; 
    }
}

class StationMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var mView;
    
    function initialize(view) {
        Menu2InputDelegate.initialize();
        mView = view;
    }
    
    function onSelect(item) {
        var id = item.getId();
        mView.setStation(id);
        mView.makeRequest();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
