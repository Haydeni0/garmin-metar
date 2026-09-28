using Toybox.WatchUi;
using Toybox.Application;
import Toybox.Lang;

class NearbyMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var mView;
    hidden var mMenu as WatchUi.Menu2;
    hidden var mService as NearbyAirportsService;
    hidden var mLoaded as Boolean = false;

    function initialize(view, menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        mView = view;
        mMenu = menu;
        mService = new NearbyAirportsService();
    }

    function startSearch() as Void {
        mService.searchNearby(method(:onNearbyResult));
    }

    function onNearbyResult(success as Boolean, data as Object) as Void {
        // Remove previous status item
        var searchIdx = mMenu.findItemById("STATUS_SEARCHING");
        if (searchIdx != -1 && searchIdx != null) {
            mMenu.deleteItem(searchIdx);
        }
        var retryIdx = mMenu.findItemById("ACTION_RETRY");
        if (retryIdx != -1 && retryIdx != null) {
            mMenu.deleteItem(retryIdx);
        }

        if (success && data instanceof Array) {
            mLoaded = true;
            var airports = data as Array<Dictionary>;
            for (var i = 0; i < airports.size(); i++) {
                var ap = airports[i];
                var icao = ap[:icao] as String;
                var label = icao;
                if (ap.hasKey(:distance) && ap[:distance] != null) {
                    var d = ap[:distance];
                    if (d instanceof Float || d instanceof Double) {
                        label = icao + " (" + d.format("%.1f") + "nm)";
                    } else if (d instanceof Number) {
                        label = icao + " (" + d.toFloat().format("%.1f") + "nm)";
                    }
                }
                var sublabel = "";
                if (ap.hasKey(:name) && ap[:name] != null && !ap[:name].equals("")) {
                    sublabel = ap[:name] as String;
                }
                mMenu.addItem(new WatchUi.MenuItem(label, sublabel, icao, null));
            }
        } else {
            mLoaded = false;
            var errMsg = (data instanceof String) ? data as String : "Failed";
            mMenu.addItem(new WatchUi.MenuItem(errMsg, "Select to retry", "ACTION_RETRY", null));
        }
        WatchUi.requestUpdate();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Application.getApp().resetTimer();
        var id = item.getId();
        if (id != null && id.equals("ACTION_RETRY")) {
            var retryIdx = mMenu.findItemById("ACTION_RETRY");
            if (retryIdx != -1 && retryIdx != null) {
                mMenu.deleteItem(retryIdx);
            }
            mMenu.addItem(new WatchUi.MenuItem("Searching...", null, "STATUS_SEARCHING", null));
            startSearch();
            return;
        }

        if (id != null && !id.equals("STATUS_SEARCHING")) {
            mView.setStation(id);
            mView.makeRequest();
            // Pop nearby menu and station menu back to main weather view
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function isLoaded() as Boolean {
        return mLoaded;
    }

    function onBack() as Void {
        mService.cancel();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function getService() as NearbyAirportsService {
        return mService;
    }
}
