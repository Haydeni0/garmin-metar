# Garmin METAR App

A Connect IQ app for Garmin Venu 4 (Currently just testing on `venu445mm`) that displays real-time METAR weather data, using the [AVWX API](https://avwx.rest).

> **Note**: This app is experimental, built as quick as possible for personal use.

## Features
- **Real-time Weather**: Fetches raw METAR strings.
- **Station Selection**: Select from a list of airports (e.g., JFK, LHR) via the on-watch menu.
  - Stations are configured via App Settings.

## Development notes

### Prerequisites
- [VS Code](https://code.visualstudio.com/)
- [Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
- [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)
- AVWX API Token (Free tier available at [avwx.rest](https://avwx.rest))

### Setup
1.  **Clone the repository**.
2.  **Configure Settings**:
    - The API Token, Default Station, and Station List are now configured via **App Settings**.
    - **In Simulator**: Go to **File > Edit Persistent Storage > Edit Application.Properties data**
    - **Note**: Paste your AVWX API Token into the field labeled **"AvwxToken"** and click **Save** to apply.
    - **On Device**: Use the Garmin Connect App or Garmin Express.

### Running locally
1.  Open the project in VS Code.
2.  Go to **Run and Debug** (`Ctrl+Shift+D`).
3.  Select **"Simulate App"** and press Play.
4.  **Important**: In the Simulator, go to **Settings > Connection Type** and ensure **WiFi** is checked/connected to enable web requests.


### Running Tests
1.  In VS Code, open the **Command Palette** (`Ctrl+Shift+P`).
2.  Select **Monkey C: Run Tests**.
3.  Alternatively, created a **Run Configuration** in `launch.json` or select **"Run Tests"** in the Run and Debug sidebar.
