using Toybox.WatchUi;

class GarminMetarDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() {
        return true;
    }
    
    function onSelect() {
        // Trigger generic behavior if needed
        return true; 
    }
}
