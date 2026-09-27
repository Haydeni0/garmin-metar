import Toybox.Lang;

module MockDataProvider {

    function getMockPayload(mockType as String or Null, station as String or Null, isTaf as Boolean) as Dictionary {
        var stn = (station != null) ? station : "EGLL";

        if (mockType != null && mockType.equals("MOCK_AUTH_ERROR")) {
            return {
                "error" => "Invalid token",
                "status" => 401
            };
        }

        if (isTaf || (mockType != null && mockType.equals("MOCK_TAF"))) {
            return {
                "raw" => "TAF " + stn + " 271700Z 2718/2824 23013KT 9999 BKN030 BECMG 2721/2724 21008KT TEMPO 2802/2806 4000 -RA BKN012 PROB30 2804/2806 2500 BCFG BKN004 BECMG 2808/2811 24015G25KT",
                "station" => stn,
                "flight_rules" => "MVFR"
            };
        }

        if (mockType != null && (mockType.equals("MOCK_IFR_LONG") || mockType.equals("MOCK_LONG") || mockType.equals("MOCK_LIFR"))) {
            return {
                "raw" => stn + " 271951Z 04018G28KT 1/2SM R04R/2400FT +SN FZFG VV004 M02/M04 A2985 RMK AO2 PK WND 05032/1944 SLP108 T10221044",
                "station" => stn,
                "flight_rules" => "LIFR"
            };
        }

        if (mockType != null && mockType.equals("MOCK_MVFR")) {
            return {
                "raw" => stn + " 271850Z 22010KT 7000 -RA BKN015 OVC025 17/14 Q1011",
                "station" => stn,
                "flight_rules" => "MVFR"
            };
        }

        // Default: VFR
        return {
            "raw" => stn + " 271950Z AUTO 27012KT 9999 FEW014 18/16 Q1014",
            "station" => stn,
            "flight_rules" => "VFR"
        };
    }
}
