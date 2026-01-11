# Garmin METAR Watch Face

A Connect IQ app for Garmin Venu 4 (simulated as `venu445mm` or `venu3`) that displays real-time METAR weather data from the AVWX API.

## Features
- **Real-time Weather**: Fetches raw METAR strings.
- **Station Selection**: Select from a list of airports (e.g., JFK, LHR) via the on-watch menu.
- **Dynamic List**: Stations are loaded from `resources/json/stations.json`.
- **Offline Handling**: Graceful error messages and "Loading..." states.

## Prerequisites
- [VS Code](https://code.visualstudio.com/)
- [Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
- [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)
- AVWX API Token (Free tier available at [avwx.rest](https://avwx.rest))

## Setup
1.  **Clone the repository**.
2.  **Configure API Key**:
    - Creation: `resources/secrets/secrets.xml`
    - Content:
      ```xml
      <strings>
          <string id="AvwxToken">YOUR_TOKEN_HERE</string>
      </strings>
      ```
    - *Note: This file is ignored by git.*

## Running locally
1.  Open the project in VS Code.
2.  Go to **Run and Debug** (`Ctrl+Shift+D`).
3.  Select **"Simulate App"** and press Play.
4.  **Important**: In the Simulator, go to **Settings > Connection Type** and ensure **WiFi** is checked/connected to enable web requests.

## Customization
- **Add Stations**: Edit `resources/json/stations.json` to add new ICAO codes.
