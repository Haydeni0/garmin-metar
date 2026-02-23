using Toybox.WatchUi;
using Toybox.Application;
using Toybox.Math;
import Toybox.Lang;

class GarminMetarDelegate extends WatchUi.BehaviorDelegate {

    hidden var mView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onMenu() {
        Application.getApp().resetTimer();
        return true;
    }
    
    // Capture interactions to reset the inactivity timer
    function onKey(keyEvent) {
        Application.getApp().resetTimer();
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            mView.scroll(1);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            mView.scroll(-1);
            return true;
        }
        return false; // Allow default behavior
    }
    
    hidden var mLastDragX = null;
    hidden var mLastDragY = null;
    hidden var mIsVerticalDrag = false;
    
    function onDrag(dragEvent) {
        if (!mView.isShowingTaf()) { return false; }
        
        var coord = dragEvent.getCoordinates();
        var type = dragEvent.getType(); // e.g. WatchUi.DRAG_TYPE_START
        
        if (type == WatchUi.DRAG_TYPE_START) {
            mLastDragX = coord[0];
            mLastDragY = coord[1];
            mIsVerticalDrag = false;
            return false;
        } else if (type == WatchUi.DRAG_TYPE_CONTINUE) {
            if (mLastDragX != null && mLastDragY != null) {
                var deltaX = coord[0] - mLastDragX;
                var deltaY = coord[1] - mLastDragY;

                if (!mIsVerticalDrag && deltaY.abs() > deltaX.abs() && deltaY.abs() > 5) {
                    mIsVerticalDrag = true;
                }

                if (mIsVerticalDrag) {
                    mView.applyScrollDelta(deltaY.toFloat());
                    mLastDragX = coord[0];
                    mLastDragY = coord[1];
                    return true;
                }
            }
        } else if (type == WatchUi.DRAG_TYPE_STOP) {
            mLastDragX = null;
            mLastDragY = null;
            mIsVerticalDrag = false;
        }
        
        return false;
    }

    
    function onTap(clickEvent) {
        Application.getApp().resetTimer();
        return false;
    }
    
    function onSwipe(swipeEvent) {
        Application.getApp().resetTimer();
        
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_LEFT || dir == WatchUi.SWIPE_RIGHT) {
            mView.toggleTaf();
            return true;
        } else if (dir == WatchUi.SWIPE_UP) {
            mView.scroll(-1);
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            mView.scroll(1);
            return true;
        }
        
        return false;
    }
    
    function onSelect() {
        Application.getApp().resetTimer();
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
        Application.getApp().resetTimer();
        var id = item.getId();
        mView.setStation(id);
        mView.makeRequest();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
