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
        Application.getApp().resetTimer();
        return pushStationMenu();
    }
    
    // Capture interactions to reset the inactivity timer
    function onKey(keyEvent) {
        return handleKey(keyEvent.getKey());
    }

    function handleKey(key) {
        Application.getApp().resetTimer();
        if (key == WatchUi.KEY_ENTER) {
            mView.toggleTaf();
            return true;
        } else if (key == WatchUi.KEY_MENU) {
            return pushStationMenu();
        } else if (key == WatchUi.KEY_UP) {
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
        return handleDrag(dragEvent.getType(), dragEvent.getCoordinates());
    }

    function handleDrag(type, coord) {
        Application.getApp().resetTimer();
        if (!mView.isShowingTaf()) { return false; }
        
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
        return handleTap();
    }

    function handleTap() {
        Application.getApp().resetTimer();
        return pushStationMenu();
    }
    
    function onSwipe(swipeEvent) {
        return handleSwipe(swipeEvent.getDirection());
    }

    function handleSwipe(dir) {
        Application.getApp().resetTimer();
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
        return false;
    }

    function pushStationMenu() as Boolean {
        Application.getApp().resetTimer();
        var menu = new WatchUi.Menu2({:title=>"Select Station"});
        
        // Add Nearby Airports discovery as top action
        menu.addItem(new WatchUi.MenuItem("Nearby Airports", null, "ACTION_NEARBY", null));

        var listStr = Application.Properties.getValue("StationList");
        var stations = StationUtils.getStations(listStr);
        for (var i = 0; i < stations.size(); i++) {
            var code = stations[i];
            menu.addItem(new WatchUi.MenuItem(code, null, code, null));
        }
        
        WatchUi.pushView(menu, new StationMenuDelegate(mView), WatchUi.SLIDE_UP);
        return true; 
    }
}

class StationMenuDelegate extends InactivityMenu2Delegate {
    hidden var mView;
    
    function initialize(view) {
        InactivityMenu2Delegate.initialize();
        mView = view;
    }
    
    function onSelect(item) {
        Application.getApp().resetTimer();
        var id = item.getId();
        if (id != null && id.equals("ACTION_NEARBY")) {
            var nearbyMenu = new WatchUi.Menu2({:title=>"Nearby Airports"});
            nearbyMenu.addItem(new WatchUi.MenuItem("Searching...", null, "STATUS_SEARCHING", null));
            var nearbyDelegate = new NearbyMenuDelegate(mView, nearbyMenu);
            WatchUi.pushView(nearbyMenu, nearbyDelegate, WatchUi.SLIDE_LEFT);
            nearbyDelegate.startSearch();
            return;
        }

        mView.setStation(id);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onBack() as Void {
        Application.getApp().resetTimer();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}




