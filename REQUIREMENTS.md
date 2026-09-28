# Requirements and UX Specifications

Living document defining expected user experience, configuration, device behaviors, and constraints for GarminMetar.

## 1. App Overview
Garmin Connect IQ watch app displaying real-time aviation weather reports (METAR and TAF) from the AVWX REST API.

## 2. Default Views & Screen States
- **Startup Mode**: Initial view displays the METAR report for the active station.
- **Toggle View**: User switches between METAR and TAF via horizontal touch swipe (`SWIPE_LEFT` / `SWIPE_RIGHT`) or physical Select/Start button (`onSelect()`).
- **Loading State**: Displays `"Loading METAR: <ICAO>..."` or `"Loading TAF: <ICAO>..."`.
- **Status Codes & Errors**:
  - Missing token: `"Set Token in App Settings"`
  - Unauthorized (401/403): `"Error: 401\nCheck App Settings"`
  - Other HTTP status: `"Error: <code>"`
  - Corrupt payload: `"Bad Format"`

## 3. Power & Lifecycle
- **Auto-Exit Inactivity Timer**: Default 30 seconds.
- **Timer Options**: 30 seconds (default), 60 seconds (1 min), 120 seconds (2 min), 0 (Unlimited / disabled).
- **Inactivity Reset**: Any user keypress, screen tap, or drag gesture resets the inactivity timer.
- **Exit Action**: When timeout elapses, the app calls `System.exit()`.

## 4. Airport Station Management
- **Startup Station**: Loads from `TargetStation` setting (default `EGWU`).
- **Station Menu**: Opened via `onMenu()` (Menu button on 5-button watches) or screen tap (`onTap()` on touchscreen watches).
  - Top action item: `"Nearby Airports"` (launches GPS-based airport discovery).
  - Configured stations: Parsed from `StationList` setting and sorted alphabetically.
- **Nearby Airports Discovery**:
  - Selecting `"Nearby Airports"` pushes a nested `Menu2` titled `"Nearby Airports"`.
  - Coordinates acquired via `Toybox.Position` (`Positioning` permission).
  - Fetches 5 closest reporting stations via `https://avwx.rest/api/station/near/{lat},{lon}?n=5`.
  - Populates menu with 5 nearest airport items displaying ICAO and distance/name sublabels.
  - Fallback / Error states: Displays `"No GPS Fix"` or error description with a select-to-retry action item.
  - Mock mode: When token begins with `MOCK`, provides 5 deterministic nearby airport fixtures without GPS or network.
  - Selecting a nearby airport sets the active station, triggers weather fetch, and pops menus back to main view.
- **Selection Scope**: Selecting a station updates the view and fetches data for the active session only. Does not overwrite the `TargetStation` property. Next app launch reverts to configured default.

## 5. Network & Caching
- **Network Triggers**: HTTP GET request to AVWX API issued on initial show, station change, or view toggle (METAR <-> TAF).
- **Session Caching**: None. Each toggle between METAR and TAF makes a fresh web request.
- **Mock Token**: Tokens starting with `MOCK` bypass network calls and return deterministic mock payloads for offline testing and visual verification.

## 6. Scrolling & Navigation
- **Scrolling Controls**:
  - Touch: Vertical drag (`onDrag`) on TAF view; vertical swipe (`SWIPE_UP` / `SWIPE_DOWN`) on both views.
  - Buttons: Up button (`KEY_UP`) scrolls upward; Down button (`KEY_DOWN`) scrolls downward.
- **Boundary Clamping**: Top scroll clamped at `0` (`mScrollY <= 0`). Bottom scroll is unbounded.

## 7. Device Archetypes & Display Profiles
- **Round Displays** (Fenix, Forerunner, Venu):
  - Full-screen text display, centered vertically and horizontally.
  - No header bar or flight category badge.
- **Semi-Octagon Displays with Subscreen** (Instinct 2, Instinct Crossover):
  - Cutout subscreen circle: displays flight rules badge (`VFR`, `MVFR`, `IFR`, `LIFR`, or `TAF` / `MET`).
  - Header: station ICAO code and divider line (`y = 68`).
  - Report text positioned below cutout (`y >= 68`), left-justified.
- **Rectangular Displays** (Venu Sq):
  - Top header: station ICAO code on left, flight category or TAF badge on right, divider line.
  - Report text positioned below header, left-justified.

## 8. App Settings (Garmin Connect)
Configured via Garmin Connect Mobile or Garmin Express:
1. `AvwxToken` (AlphaNumeric, string): AVWX API Bearer token. Default: `"YOUR_TOKEN_HERE"`.
2. `TargetStation` (AlphaNumeric, string): Default airport ICAO code. Default: `"EGWU"`.
3. `StationList` (AlphaNumeric, string): Comma-separated list of airport ICAO codes. Default: `"EGWU,EGLL,EGUB,EGVO,KJFK,KLAX"`.
4. `AutoExitSeconds` (List, number): Inactivity auto-exit timer duration (30, 60, 120, 0). Default: `30`.
