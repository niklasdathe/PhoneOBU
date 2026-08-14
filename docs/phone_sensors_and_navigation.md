# Phone sensors, localization and navigation

## Captured phone data

`PhoneSensorsRepository` exposes one timestamped stream containing:

- accelerometer including gravity (m/s²);
- user acceleration with gravity removed (m/s²);
- gyroscope (rad/s);
- magnetometer (µT);
- barometric pressure where hardware provides it (hPa);
- latitude, longitude and altitude;
- horizontal and vertical location accuracy;
- ground speed and speed accuracy;
- GNSS/fused course and course accuracy;
- a basic accelerometer/magnetometer-derived roll, pitch and compass/yaw
  orientation with explicit derivation provenance.

The platform location is not raw GPS only. Android normally supplies its fused location provider and iOS supplies Core Location, which may combine GNSS, Wi-Fi, cellular and motion information. The app preserves accuracy values so downstream fusion can reject weak fixes.

The derived orientation is useful for diagnostics, but it is not a production
GNSS/INS estimate. Raw vectors, OS-fused values and derived orientation are
stored separately with their own acquisition timestamps.

## Modes

- `PHONE_SENSORS=live` (default): physical device streams and runtime location permission.
- `PHONE_SENSORS=demo`: deterministic 10 Hz Hamburg motion/location replay. Use this for emulator, iOS Simulator and repeatable screenshots.
- `OBU_TRANSPORT=demo` (default): simulated S3/V2X/bicycle telemetry.
- `OBU_TRANSPORT=ble`: real ESP32-S3 GATT transport.

The two switches are independent, so all four hardware/simulation combinations are testable.

## Navigation

The riding screen uses:

1. OpenStreetMap raster tiles through `flutter_map`;
2. Nominatim for typed destination search;
3. long press on the map as an address-search-free destination input;
4. Valhalla with `costing=bicycle` for route geometry, ETA and maneuvers;
5. phone location to follow the rider and advance the current maneuver.

The service is intentionally behind `NavigationService`; provider choice cannot
change the BLE/OBU protocol. Valhalla is a prototype candidate and
`providerFrozen` remains false until the NAV-004 Hamburg benchmark and Q-001 /
Q-002 decisions are complete. Public OSM/Valhalla/Nominatim endpoints are
suitable only for low-volume prototype testing and require attribution/fair
use.

## Device verification checklist

1. Deny and grant location permission; verify the diagnostic state changes.
2. Disable platform location services; verify a visible unavailable/error state.
3. Compare stationary accelerometer magnitude with approximately 9.81 m/s².
4. Rotate the phone and verify gyroscope/magnetometer updates.
5. Check whether the specific phone has a barometer; unavailable is valid hardware behavior.
6. Walk or ride outdoors and compare speed/course against the platform map app.
7. Search and select a destination, then confirm bicycle route geometry and step progression.
8. Lock the phone during a deliberately started ride and test on every supported OS version. Background location and BLE lifecycle behavior cannot be validated in a simulator.
