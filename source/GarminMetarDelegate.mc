using Toybox.WatchUi;
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
        var stations = WatchUi.loadResource(Rez.JsonData.Stations) as Array<String>;
        
        // Sort stations alphabetically
        for (var i = 0; i < stations.size(); i++) {
            for (var j = i + 1; j < stations.size(); j++) {
                if (stations[i].compareTo(stations[j]) > 0) {
                    var temp = stations[i];
                    stations[i] = stations[j];
                    stations[j] = temp;
                }
            }
        }
        
        for (var i = 0; i < stations.size(); i++) {
            var code = stations[i];
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
