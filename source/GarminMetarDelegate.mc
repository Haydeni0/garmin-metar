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
            stations = StationUtils.parseStationString(listStr);
        }
        
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
