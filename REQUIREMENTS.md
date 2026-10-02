# Requirements and UX Specifications

Living specification defining user experience, device behaviors, settings, and constraints for GarminMetar. Every requirement is mapped to automated verification tests.

## 1. Core Views & Screen States

### [REQ-VIEW-01] Startup View
- **Statement**: On app launch, the initial view MUST display the METAR report for the active station.
- **Verification**: `AppLifecycleTests.testInitialViewContract`, `ViewDataTests.testParseVfrPayload`

### [REQ-VIEW-02] METAR and TAF View Toggle
- **Statement**: User MUST be able to toggle between METAR and TAF via horizontal touch swipe (`SWIPE_LEFT` / `SWIPE_RIGHT`) or physical Select/Start button (`KEY_ENTER`).
- **Verification**: `DelegateTests.testSwipeLeftTogglesTaf`, `DelegateTests.testSwipeRightTogglesBackToMetar`, `DelegateTests.testKeyEnterTogglesTaf`

### [REQ-VIEW-03] Loading State
- **Statement**: While network requests are in flight, the view MUST display `"Loading METAR: <ICAO>..."` or `"Loading TAF: <ICAO>..."`.
- **Verification**: `AppLifecycleTests.testInitialViewContract`, `ViewDataTests.testInitialLayoutShowsStationLoadingString`

### [REQ-VIEW-04] Error State Handling
- **Statement**: Network and payload errors MUST be rendered with actionable descriptions:
  - Missing token: `"Set Token in App Settings"`
  - Unauthorized (401/403): `"Error: 401\nCheck App Settings"` or `"Error: 403\nCheck App Settings"`
  - Other HTTP status: `"Error: <code>"`
  - Bluetooth timeout: `"Error: -104"`
  - Corrupt payload: `"Bad Format"`
  When a 200 response payload lacks a valid raw report string, the view MUST display `"Bad Format"` and clear any active flight rules category badge (`mFlightRules = null`).
- **Verification**: `ViewDataTests.testMissingTokenPrompt`, `ViewDataTests.testParseAuthError401`, `ViewDataTests.testParseGenericHttpError`, `ViewDataTests.testParseBleTimeoutError`, `ViewDataTests.testParseMissingRawKey`, `ViewDataTests.testMissingRawKeyWithValidFlightRulesResetsBadge`

## 2. Power & Lifecycle Management

### [REQ-PWR-01] Auto-Exit Inactivity Timer
- **Statement**: App MUST exit automatically after an inactivity duration specified by `AutoExitSeconds` (default 30 seconds; configurable to 30, 60, 120, or 0 to disable). The inactivity timer MUST run during both the primary weather view and modal menus (Station selection, Nearby discovery). User interactions in modal menus (opening the menu, wrapping, paging, or selecting) MUST reset the inactivity timer countdown.
- **Verification**: `AppLifecycleTests.testTimerStartsByDefault`, `AppLifecycleTests.testTimerStopOnAppStop`, `AppLifecycleTests.testTimerDisabledWhenZero`, `AppLifecycleTests.testSettingsChangedRefreshesTimer`, `AppLifecycleTests.testMenuRetainsActiveInactivityTimer`, `AppLifecycleTests.testStationMenuOpeningResetsTimer`, `AppLifecycleTests.testStationMenuNavigationResetsTimer`, `AppLifecycleTests.testNearbyMenuNavigationResetsTimer`



### [REQ-PWR-02] Inactivity Timer Reset
- **Statement**: Any user interaction (physical key press, screen tap, or drag gesture) MUST reset the inactivity countdown timer.
- **Verification**: `AppLifecycleTests.testInteractionResetsTimerOnKey`, `AppLifecycleTests.testInteractionResetsTimerOnTap`, `AppLifecycleTests.testInteractionResetsTimerOnSwipe`, `AppLifecycleTests.testInteractionResetsTimerOnDrag`, `AppLifecycleTests.testInteractionResetsTimerOnSelect`

### [REQ-PWR-03] Exit Action
- **Statement**: When the inactivity timer expires, the app MUST call `System.exit()` to terminate and save battery.
- **Verification**: `AppLifecycleTests.testTimerStartsByDefault`

## 3. Station Management

### [REQ-STN-01] Default Startup Station & Closest Fallback
- **Statement**: Active station on initial launch MUST load from the `TargetStation` property (default `EGWU`). If `TargetStation` is unset or blank, the app MUST automatically query GPS via `NearbyAirportsService` and load the closest reporting airport. If GPS fix is unavailable or times out, the view MUST display `"No GPS Fix\nSelect Station"`. Manual station selection while locating MUST be preserved.
- **Verification**: `AppLifecycleTests.testInitialViewContract`, `StationTests.testUnsetTargetStationTriggersClosestAirport`, `StationTests.testClosestAirportFailureShowsFallback`, `StationTests.testUnsetTargetStationPropertyDefaultsToClosest`, `StationTests.testManualSelectionDuringLocatingIsNotOverwritten`

### [REQ-STN-02] Station Selection Menu
- **Statement**: Station selection menu MUST open via `onMenu()` (Menu key on 5-button devices) or screen tap (`onTap()` on touchscreens). The top item MUST be `"Nearby Airports"`, followed by configured stations from `StationList` in their exact configured order.
- **Verification**: `DelegateTests.testOnMenuOpensStationMenu`, `DelegateTests.testTapOpensStationMenu`, `StationTests.testParseSimpleList`, `StationTests.testParseWithSpaces`, `StationTests.testGetStationsPreservesConfiguredOrder`, `StationTests.testGetStationsNullHandledSafely`

### [REQ-STN-03] Session-Only Selection Scope
- **Statement**: Selecting an airport updates the view and triggers weather queries for the active session only; it MUST NOT overwrite the configured `TargetStation` property.
- **Verification**: `DelegateTests.testStationChangeResetsScroll`, `NearbyAirportsTests.testStationMenuDelegateSelectsNearby`

## 4. Nearby Airport Discovery (GPS)

### [REQ-GPS-01] Discovery Menu Activation
- **Statement**: Selecting `"Nearby Airports"` MUST push a `Menu2` titled `"Nearby Airports"` with a `"Searching..."` status item while coordinates and airfields are being queried. Selecting an airfield item in the Nearby Airports menu MUST assign the station, mark data for refresh, and pop navigation back to the primary weather view.
- **Verification**: `NearbyAirportsTests.testStationMenuDelegateSelectsNearby`, `NearbyAirportsTests.testNearbyMenuDelegatePopulatesItems`, `NearbyAirportsTests.testNearbyMenuDelegateOnSelectHandling`

### [REQ-GPS-02] Coordinate Bounds & Sentinel Validation
- **Statement**: Acquired GPS coordinates MUST be validated within geographic bounds (`[-90.0, 90.0]` latitude, `[-180.0, 180.0]` longitude). Garmin's uninitialized sentinel coordinate `[180.0, 180.0]` MUST be rejected as invalid.
- **Verification**: `NearbyAirportsTests.testCoordinateValidation`, `NearbyAirportsTests.testSimulatorUninitializedLocationRejected`, `NearbyAirportsTests.testFetchFromAvwxRejectsSentinelCoordinates`, `NearbyAirportsTests.testFetchFromAvwxRejectsOutOfBoundsCoordinates`

### [REQ-GPS-03] GPS Acquisition Timeout
- **Statement**: GPS listening MUST time out after 8 seconds if no valid fix is acquired, disabling location listeners and presenting `"No GPS Fix"` with a `"Select to retry"` action item. When the user backs out of discovery (`onBack()`) or the view is hidden (`onHide()`), all active location listeners and timers MUST be cancelled immediately to conserve battery. The service MUST validate API token configuration prior to initiating GPS listening; if the token is unset or default, discovery MUST fail immediately with `'Token Missing'` without powering on GPS hardware.
- **Verification**: `NearbyAirportsTests.testGpsTimeoutTriggersError`, `NearbyAirportsTests.testNearbyMenuDelegateErrorHandling`, `NearbyAirportsTests.testNearbyMenuDelegateOnBackCancelsSearch`, `StationTests.testSetStationCancelsActiveGpsSearch`, `NearbyAirportsTests.testEmptyArrayTriggersNoAirportsFoundError`, `NearbyAirportsTests.testSearchNearbyWithoutTokenRejectsImmediatelyWithoutGps`

### [REQ-GPS-04] AVWX Station Query & Result Limit
- **Statement**: Service MUST query `https://avwx.rest/api/station/near/{lat},{lon}?n={NearbyCount}` and parse up to `NearbyCount` reporting airfields (default 5, configurable 1-20 in settings) using `"nautical_miles"`, `"distance"`, or `"miles"`.
- **Verification**: `NearbyAirportsTests.testParseNearbyResponseNauticalMiles`, `NearbyAirportsTests.testParseNearbyResponseNested`, `NearbyAirportsTests.testParseNearbyResponseFlat`, `NearbyAirportsTests.testParseNearbyResponseClampedToFive`, `NearbyAirportsTests.testParseNearbyResponseEmpty`, `NearbyAirportsTests.testNearbyCountConfigurable`, `NearbyAirportsTests.testNearbyCountDefaultIsFive`

### [REQ-GPS-05] Menu Item Formatting with Distance
- **Statement**: Nearby airport items MUST display the ICAO code and distance in nautical miles in the primary label (`<ICAO> (<dist>nm)`, e.g. `"EGLL (4.2nm)"`) to prevent truncation, with airport name in the sublabel.
- **Verification**: `NearbyAirportsTests.testNearbyMenuDelegatePopulatesItems`

### [REQ-GPS-06] Simulated GPS Fallback
- **Statement**: When watch GPS has no fix, service MUST check the `SimulatedGps` setting (`lat,lon`), validate coordinates, and query AVWX using those coordinates for simulator debugging.
- **Verification**: `NearbyAirportsTests.testParseCoordinates`

### [REQ-GPS-07] Offline Mock Airports
- **Statement**: When the active token begins with `MOCK`, nearby airport discovery MUST return 5 deterministic mock airfields immediately without GPS or network calls.
- **Verification**: `NearbyAirportsTests.testMockNearbyAirports`

## 5. Network & Caching

### [REQ-NET-01] Network Request Triggers
- **Statement**: HTTP GET requests to AVWX API MUST be issued on initial show, station change, or view toggle (METAR <-> TAF).
- **Verification**: `ViewDataTests.testMockVfrIntegration`, `ViewDataTests.testMockTafIntegration`

### [REQ-NET-02] Fresh Web Requests
- **Statement**: The app MUST NOT cache reports between view toggles; each toggle issues a fresh request.
- **Verification**: `ViewDataTests.testMockVfrIntegration`

### [REQ-NET-03] Offline Mock Payloads
- **Statement**: When `AvwxToken` starts with `MOCK`, network calls MUST be bypassed, returning deterministic mock payloads for VFR, IFR, and TAF states.
- **Verification**: `LayoutProfileTests.testMockDataProviderVfr`, `LayoutProfileTests.testMockDataProviderIfrLong`, `LayoutProfileTests.testMockDataProviderTaf`, `ViewDataTests.testMockVfrIntegration`, `ViewDataTests.testMockTafIntegration`

### [REQ-NET-04] Request Deduplication & Lifecycle Optimization
- **Statement**: The application MUST NOT dispatch duplicate concurrent HTTP requests for the same station and report type. Returning to the main view from menus without changing the target station MUST NOT re-trigger network requests if reports are already loaded. Re-selecting the currently active station in the station menu MUST mark the data stale and trigger a single refresh request upon view return. Asynchronous HTTP responses MUST be tagged with a monotonically increasing sequence ID. Responses corresponding to superseded requests (e.g. from prior station selections or report mode toggles) MUST be discarded without modifying active view state or in-flight tracking.
- **Verification**: `StationTests.testMenuReturnTriggersSingleRequest`, `StationTests.testMenuCancelDoesNotTriggerDuplicateRequest`, `StationTests.testStationReselectionTriggersRefresh`, `StationTests.testStaleResponseIgnoredOnStationChange`

## 6. Scrolling & Navigation

### [REQ-NAV-01] Touch Gesture Scrolling
- **Statement**: Vertical drag (`onDrag`) MUST scroll text in TAF view. Vertical swipe (`SWIPE_UP` / `SWIPE_DOWN`) MUST scroll in both METAR and TAF views.
- **Verification**: `DelegateTests.testTouchDragAppliedOnTaf`, `DelegateTests.testTouchDragIgnoredOnMetar`, `DelegateTests.testSwipeUpAndDownScroll`

### [REQ-NAV-02] Physical Button Scrolling
- **Statement**: Pressing Up (`KEY_UP`) MUST scroll upward; pressing Down (`KEY_DOWN`) MUST scroll downward.
- **Verification**: `DelegateTests.testKeyScrollDownAndUp`

### [REQ-NAV-03] Scroll Clamping & Resets
- **Statement**: Top scroll MUST be clamped at 0 (`mScrollY <= 0`). Changing station or toggling between METAR/TAF MUST reset scroll position to 0.
- **Verification**: `DelegateTests.testScrollClampedAtTop`, `DelegateTests.testStationChangeResetsScroll`, `DelegateTests.testToggleTafResetsScroll`

## 7. Device Archetypes & Display Profiles

### [REQ-ARCH-01] Round Displays (Fenix, Forerunner, Venu)
- **Statement**: Round screen profile MUST display full-screen centered text without header bar or category badges.
- **Verification**: `LayoutProfileTests.testRoundProfile`

### [REQ-ARCH-02] Semi-Octagon Displays with Subscreen (Instinct Series)
- **Statement**: On semi-octagon watches with subscreen circle cutouts, text MUST stay below the cutout (`contentY = 58` for Instinct 40mm [166x166 screen / 52x52 subscreen]; `contentY = 68` for 45mm/50mm [176x176+ screen / 62x62 subscreen]), header MUST display station code and divider, and subscreen circle MUST display the flight rules badge (`VFR`, `MVFR`, `IFR`, `LIFR`, `TAF`, or `MET`).
- **Verification**: `LayoutProfileTests.testInstinctProfile`, `LayoutProfileTests.testInstinct40mmProfile`

### [REQ-ARCH-03] Rectangular Displays (Venu Sq, Edge)
- **Statement**: Rectangular profile MUST render a top header with station ICAO on left, flight category or TAF badge on right, divider line, and text below header.
- **Verification**: `LayoutProfileTests.testRectangleProfile`

## 8. App Configuration Properties

### [REQ-CFG-01] Persistent App Properties
- **Statement**: App MUST support persistent configuration properties:
  - `AvwxToken` (string, default `"YOUR_TOKEN_HERE"`)
  - `TargetStation` (string, default `"EGWU"`, title `"Default Station (blank for closest)"`)
  - `StationList` (string, default `"EGWU,EGLL,EGUB,EGVO,KJFK,KLAX"`)
  - `AutoExitSeconds` (number, default `30`)
  - `NearbyCount` (number, default `5`, title `"Nearby Airports Count"`)
  - `SimulatedGps` (string, default `""`)
- **Verification**: `ViewDataTests.testMissingTokenPrompt`, `StationTests.testParseSimpleList`, `StationTests.testUnsetTargetStationPropertyDefaultsToClosest`, `AppLifecycleTests.testTimerStartsByDefault`, `NearbyAirportsTests.testNearbyCountConfigurable`, `NearbyAirportsTests.testNearbyCountDefaultIsFive`

## 9. Developer Tooling & Environment

### [REQ-DEV-01] Developer CLI Surface
- **Statement**: All build, test, and simulation commands MUST be runnable via `uv run scripts/dev.py` (`test`, `build`, `capture`, `matrix`, `sync-settings`).
- **Verification**: Automated test runner execution via `scripts/dev.py`

### [REQ-DEV-02] Local Environment Settings Sync
- **Statement**: Untracked `.env` configuration (templated from `.env.example`) MUST be synced into binary Connect IQ simulator settings (`GARMINMETAR.SET` and `TEST.SET`) via VS Code `preLaunchTask` before debug launch.
- **Verification**: `NearbyAirportsTests.testParseCoordinates`
