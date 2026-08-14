# Verification evidence for 1.0.0+3

Date: 2026-08-13

## Completed in the source-audit environment

- Reviewed all six sheets of `BicycleOBU_Requirements_v1_0.xlsx`, including
  the 177-row requirements matrix, open questions, architecture decisions,
  design candidates and sources.
- Ran `tool/verify_requirements.sh`: all fail-closed source invariants passed.
- Parsed every Dart source/test file with a current Tree-sitter Dart grammar:
  no syntax-error or missing-token nodes.
- Parsed `pubspec.yaml` as YAML.
- Parsed Android `AndroidManifest.xml` and iOS `Info.plist` as XML.
- Ran POSIX shell syntax checks for every script in `tool/`.
- Audited constructors and interface implementations after the transport,
  navigation, sensor, recording and replay model changes.

## Automated tests included

- BLE frame CRC, ATT-size fragmentation/reassembly, per-stream loss and
  out-of-order detection.
- CAM/VAM/C-ITS dispatch and modular security-validator behavior.
- GLOSA later-green selection, comfortable-speed bound, missing timing,
  ambiguous association and stale MAPEM rejection.
- DENM active-event deduplication.
- Shared live/replay C-ITS/GLOSA processing.
- DBC parsing plus Intel and Motorola signal decoding.
- Raw-record round trip and OTM live-only eligibility.
- Settings/pose provenance and OTM-disabled default.
- Deterministic phone sensors, replaceable navigation and primary ride UI.

## Not executable in this environment

Flutter and Dart SDK binaries were not installed, so `dart format`,
`flutter analyze`, `flutter test`, Android Gradle compilation and Xcode
compilation were not executed here. Run:

```bash
./tool/bootstrap_platforms.sh
./tool/verify.sh
./tool/build_test_apps.sh
```

The physical/integration acceptance runs in
`requirements_traceability.md` remain mandatory before declaring the complete
prototype requirements compliant.
