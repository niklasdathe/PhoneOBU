# Phone OBU

[![Repository checks](https://github.com/niklasdathe/PhoneOBU/actions/workflows/flutter.yml/badge.svg)](https://github.com/niklasdathe/PhoneOBU/actions/workflows/flutter.yml)

Flutter application for the Bicycle OBU. The phone provides the rider
interface, navigation, C-ITS interpretation, ride recording and replay. It
connects to the ESP32-S3 hub over Bluetooth Low Energy.

This is a research prototype. Experimental safety functions are not certified
and do not replace rider attention.

## Status

| Area | Current evidence |
|---|---|
| Application | Android and iOS platform configuration; primary ride, diagnostics, sessions, settings and about screens |
| OBU transport | Versioned BLE records, fragmentation, CRC, reconnect and sequence diagnostics implemented |
| C-ITS | Normalized CAM, VAM, DENM, MAPEM, SPATEM and IVIM processing implemented; ETSI reference-vector validation pending |
| Navigation | Replaceable Valhalla bicycle-routing adapter; provider decision pending |
| Recording | Canonical JSONL sessions, CSV/PCAPNG export and deterministic replay implemented |
| Verification | Source invariants and unit/widget tests included; device, endurance and physical integration tests pending |

## Start here

| Goal | Guide |
|---|---|
| Build and verify the application | [Development workflow](#development-workflow) |
| Review the BLE contract | [OBU transport](docs/obu_transport.md) |
| Review phone sensors and navigation | [Phone sensors and navigation](docs/phone_sensors_and_navigation.md) |
| Trace requirements to implementation | [Requirements traceability](docs/requirements_traceability.md) |
| Review executed and pending evidence | [Verification evidence](docs/verification_evidence.md) |
| Find a technical document | [Documentation index](docs/README.md) |

## Architecture

```text
Flutter UI
   |
ObuController
   |-- ObuRepository -------- Demo or ESP32-S3 BLE
   |-- PhoneSensorsRepository Live or deterministic simulation
   |-- NavigationService ----- Replaceable bicycle routing provider
   |-- RideSessionManager ---- Canonical log, exports and replay
   `-- OtmPublisher ----------- Explicit live-only opt-in
```

The ESP32-C5 remains the ITS-G5 radio processor and the ESP32-S3 remains the
embedded hub. Local display, warning and recording paths do not depend on
OpenTrafficMap availability.

## Development workflow

Flutter 3.35 or newer is required. Generate missing platform boilerplate once,
then run the complete verification suite:

```bash
./tool/bootstrap_platforms.sh
./tool/verify.sh
```

Run with deterministic data:

```bash
flutter run --dart-define=PHONE_SENSORS=demo
```

Run with the ESP32-S3 BLE transport and live phone sensors:

```bash
flutter run \
  --dart-define=OBU_TRANSPORT=ble \
  --dart-define=PHONE_SENSORS=live
```

Android development installation:

```bash
flutter devices
flutter run -d <android-device-id> --dart-define=OBU_TRANSPORT=ble
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

iOS builds require macOS, Xcode and an Apple development team.

## Source of truth

| Concern | Authoritative source |
|---|---|
| Package, SDK and dependency versions | [`pubspec.yaml`](pubspec.yaml) |
| BLE framing and normalized records | [`lib/protocol/obu_protocol.dart`](lib/protocol/obu_protocol.dart) |
| Application orchestration | [`lib/state/obu_controller.dart`](lib/state/obu_controller.dart) |
| Persistent settings and defaults | [`lib/models/app_settings.dart`](lib/models/app_settings.dart) |
| Session format and exports | [`lib/data/session/ride_session_manager.dart`](lib/data/session/ride_session_manager.dart) |
| Requirements and acceptance state | [`docs/requirements_traceability.md`](docs/requirements_traceability.md) |
| Executed verification evidence | [`docs/verification_evidence.md`](docs/verification_evidence.md) |

## Safety and data rules

- Bicycle coordinates use the rear-wheel axle center as origin: x forward, y
  left, z up.
- Source acquisition time and phone arrival time remain separate.
- Raw, fused, derived, event and simulated records retain provenance.
- GLOSA displays no target speed for missing, invalid, stale, off-route or
  ambiguous timing input.
- OpenTrafficMap upload is disabled by default and accepts only live raw V2X
  frames. Replay and recovered records are excluded.

Do not claim complete-system compliance from source or simulation evidence.
The pending physical and integration gates are recorded in the requirements
traceability document.

## License

No project license has been selected. Until one is added, this repository must
not be presented as granting software or documentation reuse rights.
