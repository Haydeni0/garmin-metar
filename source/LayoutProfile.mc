import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.WatchUi;

class LayoutProfile {
    var shape as Symbol = :round; // :round, :semi_octagon, :rectangle
    var screenWidth as Number = 240;
    var screenHeight as Number = 240;

    var contentX as Number = 0;
    var contentY as Number = 0;
    var contentWidth as Number = 240;
    var contentHeight as Number = 240;
    var font as Graphics.FontDefinition = Graphics.FONT_XTINY;
    var justification as Number = Graphics.TEXT_JUSTIFY_CENTER;
    var tafJustification as Number = Graphics.TEXT_JUSTIFY_CENTER;
    var tafBaseY as Number = 120;

    var hasSubscreen as Boolean = false;
    var hasHeader as Boolean = false;
    var headerFont as Graphics.FontDefinition = Graphics.FONT_TINY;
    var subscreenCenterX as Number = 0;
    var subscreenCenterY as Number = 0;
    var stationX as Number = 0;
    var stationY as Number = 0;
    var stationJustify as Number = Graphics.TEXT_JUSTIFY_CENTER;
    var dividerY as Number = 0;

    function initialize(dc as Graphics.Dc or Null, settings as System.DeviceSettings or Null) {
        var w = 240;
        var h = 240;
        var screenShape = System.SCREEN_SHAPE_ROUND;
        var headerFontH = 24;

        if (dc != null) {
            w = dc.getWidth();
            h = dc.getHeight();
            headerFontH = dc.getFontHeight(Graphics.FONT_TINY);
        }
        if (settings != null && settings has :screenShape && settings.screenShape != null) {
            screenShape = settings.screenShape;
        }

        applyConfiguration(w, h, screenShape, headerFontH);
    }

    function applyConfiguration(w as Number, h as Number, screenShape as Number, headerFontH as Number) as Void {
        screenWidth = w;
        screenHeight = h;

        if (screenShape == System.SCREEN_SHAPE_SEMI_OCTAGON) {
            shape = :semi_octagon;
            hasSubscreen = true;
            hasHeader = true;
            headerFont = Graphics.FONT_TINY;

            if (screenWidth <= 166) {
                // Instinct 40mm (166x166, subscreen 52x52)
                subscreenCenterX = 138;
                subscreenCenterY = 26;
                stationX = 16;
                stationY = 12;
                dividerY = 54;
                contentY = 58;
            } else {
                // Instinct 45mm / 50mm (176x176, subscreen 62x62)
                subscreenCenterX = 144;
                subscreenCenterY = 31;
                stationX = 20;
                stationY = 16;
                dividerY = 64;
                contentY = 68;
            }

            contentX = 0;
            contentWidth = screenWidth;
            contentHeight = screenHeight - contentY;
            tafBaseY = contentY;
            justification = Graphics.TEXT_JUSTIFY_CENTER;
            tafJustification = Graphics.TEXT_JUSTIFY_CENTER;
            stationJustify = Graphics.TEXT_JUSTIFY_LEFT;

        } else if (screenShape == System.SCREEN_SHAPE_RECTANGLE) {
            shape = :rectangle;
            hasSubscreen = false;
            hasHeader = true;
            headerFont = Graphics.FONT_TINY;

            stationX = 12;
            stationY = 6;
            stationJustify = Graphics.TEXT_JUSTIFY_LEFT;
            dividerY = stationY + headerFontH + 4;

            contentX = 12;
            contentY = dividerY + 6;
            contentWidth = screenWidth - 24;
            contentHeight = screenHeight - contentY;
            tafBaseY = contentY;
            justification = Graphics.TEXT_JUSTIFY_LEFT;
            tafJustification = Graphics.TEXT_JUSTIFY_LEFT;

        } else {
            shape = :round;
            hasSubscreen = false;
            hasHeader = false;

            contentX = 0;
            contentY = 0;
            contentWidth = screenWidth;
            contentHeight = screenHeight;
            tafBaseY = screenHeight / 2;
            justification = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
            tafJustification = Graphics.TEXT_JUSTIFY_CENTER;

            subscreenCenterX = 0;
            subscreenCenterY = 0;
            stationX = 0;
            stationY = 0;
            stationJustify = Graphics.TEXT_JUSTIFY_CENTER;
            dividerY = 0;
        }
    }

    function drawHeader(dc as Graphics.Dc, station as String, flightRules as String or Null, isShowingTaf as Boolean) as Void {
        if (!hasHeader) {
            return;
        }

        // Mask header area with solid black background so scrolled text is hidden underneath
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, screenWidth, dividerY + 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (shape == :semi_octagon) {
            var circleText = isShowingTaf ? "TAF" : (flightRules != null ? flightRules : "MET");
            dc.drawText(subscreenCenterX, subscreenCenterY, Graphics.FONT_TINY, circleText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(stationX, stationY, Graphics.FONT_SMALL, station, stationJustify);
            dc.drawLine(8, dividerY, screenWidth - 8, dividerY);

        } else if (shape == :rectangle) {
            dc.drawText(stationX, stationY, headerFont, station, stationJustify);
            var badgeText = isShowingTaf ? "TAF" : (flightRules != null ? flightRules : "METAR");
            dc.drawText(screenWidth - 12, stationY, headerFont, badgeText, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.drawLine(10, dividerY, screenWidth - 10, dividerY);
        }
    }
}
