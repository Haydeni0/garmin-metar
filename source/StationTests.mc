using Toybox.Test;
import Toybox.Lang;

module StationTests {

    (:test)
    function testParseSimpleList(logger) {
        var input = "A,B,C";
        // var expected = ["A", "B", "C"];
        var actual = StationUtils.parseStationString(input);
        
        if (actual.size() != 3) {
            logger.debug("Size mismatch: " + actual.size());
            return false;
        }
        
        if (!actual[0].equals("A")) { return false; }
        if (!actual[1].equals("B")) { return false; }
        if (!actual[2].equals("C")) { return false; }
        
        return true;
    }
    
    (:test)
    function testParseWithSpaces(logger) {
        var input = "  EGWU , KJFK  ,  A  ";
        var actual = StationUtils.parseStationString(input);
        
        if (actual.size() != 3) {
            logger.debug("Size mismatch: " + actual.size());
            return false;
        }
        
        if (!actual[0].equals("EGWU")) { 
            logger.debug("0 mismatch: '" + actual[0] + "'");
            return false; 
        }
        if (!actual[1].equals("KJFK")) { 
            logger.debug("1 mismatch: '" + actual[1] + "'");
            return false; 
        }
        if (!actual[2].equals("A")) { 
            logger.debug("2 mismatch: '" + actual[2] + "'");
            return false; 
        }
        
        return true;
    }
}
