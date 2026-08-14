# Bicycle OBU v1.0 application compliance record

Authoritative baseline: `BicycleOBU_Requirements_v1_0.xlsx` (177
requirements, 154 Must). This record audits version 1.0.0+3 of the Flutter
application. It does not reinterpret embedded, RF, electrical or mechanical
requirements as phone-app obligations.

## Status vocabulary

- **Source complete** — an application implementation and automated or static
  source test exist. Acceptance may still require the workbook's physical or
  integration verification method.
- **Partial** — a material application implementation or verification gap
  remains; it is a release blocker for full requirement compliance.
- **External gate** — app source exists, but the acceptance criterion can only
  be closed with S3/C5 firmware, actual captures, services or physical phones.
- **Embedded/out of app** — the owning implementation is not in this archive.
- **Open decision** — the workbook explicitly prevents a design freeze.

## Release verdict

The previous app-source gaps in persistent settings, sensor-rate and pose
configuration, GLOSA uncertainty handling, warning provenance, raw-frame
traceability, DBC lifecycle, scientific sessions, exports/replay, background
ride support and OTM safeguards have implementation paths in this version.

Full system compliance is **not yet certifiable**. The unresolved blockers are
APP-003 reference-vector/UPER decoding, GLOSA-001 route/lane association
validation, LOG-001 endurance, NAV-004's deliberately open routing benchmark,
and the hardware/integration gates listed below. The app identifies itself as
a non-certified research
prototype while those gates remain open.

## Cross-cutting system and BLE-sensor impact

| ID | Evidence in this version | Status |
| --- | --- | --- |
| SYS-001 | App coordinates V2X, bicycle telemetry, navigation, GLOSA, warnings, logging and optional OTM in one controller/UI. | Source complete for phone scope |
| SYS-002 | Local repositories, warnings and recording do not depend on internet; navigation/OTM failures are isolated. | Source complete; offline integration gate |
| SYS-003 | Phone reconnect does not request an OBU reboot. Continued embedded acquisition/HMI is firmware-owned. | Embedded/out of app |
| SYS-004 | Diagnostics separates C5, GNSS, CAN, BLE sensors, phone BLE, storage and internet/OTM. | Source complete; fault-injection gate |
| SYS-005 | BLE envelopes carry protocol version and unknown message types cannot change subsequent frame boundaries. | Source complete; compatibility gate |
| SYS-006 | About, diagnostics and critical-warning UI visibly state research/non-certified status. | Source complete |
| BSENS-001–003 | Concurrent standard/custom bicycle-sensor links are S3 central responsibilities; app exposes configuration but does not own those GATT links. | Embedded/out of app |
| BSENS-004 | Forwarded typed records can retain sensor source, acquisition time, measurement payload and provenance in the app log. | Source complete schema; S3 integration gate |
| BSENS-005 | Isolation between embedded BLE sensor links and phone BLE is S3 firmware-owned. | Embedded/out of app |

## Phone BLE (PBLE)

| ID | Evidence in this version | Status |
| --- | --- | --- |
| PBLE-001 | One `UniversalBleObuRepository` and shared GATT UUIDs serve Android/iOS; both manifests declare BLE capabilities. | External gate: build and transfer on one Android phone and one iPhone |
| PBLE-002 | Phone performs service-filtered scan, connection, discovery, subscription and writes as central/client. | Source complete |
| PBLE-003 | Telemetry is notification-driven; command results use indications. | Source complete |
| PBLE-004 | Per-source/type sequence gaps and late/out-of-order arrivals are detected and reported without discarding subsequent valid messages. | Source complete; packet-loss integration gate |
| PBLE-005 | Application fragmentation/reassembly is independent of negotiated ATT payload; CRC and oversize-message tests exist. | Source complete |
| PBLE-006 | Auto-connect and explicit reconnect preserve the OBU; session-continuity markers are displayed/logged. | External gate: S3 reconnect/power-cycle test |
| PBLE-007 | Command request IDs return explicit success, code, message and resulting state; timeout/failure is visible. | Source complete; S3 command matrix gate |
| PBLE-008 | App exposes embedded overflow/recovery counters without blocking record consumption. Bounded embedded queues remain firmware-owned. | Embedded/out of app plus stress-test gate |
| PBLE-009 | UI and log distinguish `live`, `bufferedRecovered`, `stale`, `replay` and `unavailable`. | Source complete |

## Warnings and GLOSA

| ID | Evidence in this version | Status |
| --- | --- | --- |
| WARN-001 | Standardized DENM becomes local embedded/app hazard state, but phone-less output is S3/display-owned. | Embedded/out of app |
| WARN-002 | No advanced collision predictor is required for baseline operation. | Source complete |
| WARN-003 | `WarningCoordinator` deduplicates active DENM notifications while every raw reception enters the record stream. | Source complete; embedded dedup gate remains |
| WARN-004 | App rejects expired/irrelevant/duplicate DENM; lightweight S3 filtering remains firmware-owned. | Source complete plus embedded/out of app |
| WARN-005 | `standardizedDenm` and `inferredExperimental` provenance are distinct in model, UI and recording. | Source complete |
| GLOSA-001 | MAPEM stores intersection/approach/signal association and accepts an explicit route-match result. Actual geometry-to-planned-route selection needs a recorded Hamburg scenario. | Partial |
| GLOSA-002 | Red timing drives received-data countdown and green interval selection. | Source complete; reference-capture gate |
| GLOSA-003 | Current-green timing drives time-to-change when present. | Source complete; reference-capture gate |
| GLOSA-004 | Constant average speed uses distance/time and is unit-tested. | Source complete |
| GLOSA-005 | Repository receives the persisted comfortable maximum; the algorithm never returns a higher speed. | Source complete |
| GLOSA-006 | Algorithm skips an unreachable current interval and tests selection of a later reachable green. | Source complete |
| GLOSA-007 | Missing/empty timing returns `noSpatem`; no interval is extrapolated. | Source complete |
| GLOSA-008 | Phone-less simple GLOSA is explicitly S3-owned. | Embedded/out of app; Should |
| GLOSA-009 | Diagnostics and session model retain intersection ID/name, signal group and MAPEM/SPATEM source times. | Source complete |
| GLOSA-010 | Missing, stale, off-route, invalid or ambiguous data produces availability detail and a null speed target. | Source complete |

## Application (APP)

| ID | Evidence in this version | Status |
| --- | --- | --- |
| APP-001 | One Flutter codebase, with isolated Android/iOS background bridges. | Source complete; platform-build gate |
| APP-002 | Ride start controls native background modes; lifecycle monitoring records possible OS suspension. | External gate: four-hour locked-screen test per platform |
| APP-003 | Typed CAM, VAM/VRU, DENM, MAPEM, SPATEM and IVIM normalized decoding exists. An ETSI ASN.1 UPER codec and valid-capture reference-vector suite are not bundled. | Partial |
| APP-004 | Each C-ITS record can retain exact `rawFrameBase64`, decoded payload, raw reference, source and acquisition/arrival times. | Source complete |
| APP-005 | Accelerometer, user acceleration, gyro, magnetometer, barometer and fused location are acquired; device orientation is derived where direct API output is unavailable. | Source complete; device capability gate |
| APP-006 | Raw acceleration/gyro/magnetometer and OS-fused location/linear acceleration/derived orientation have separate identifiers and times. | Source complete |
| APP-007 | Every sensor group has explicit availability/error state; failures do not stop other streams. | Source complete; degradation test gate |
| APP-008 | Ride UI shows local OBU status, C-ITS, navigation state, GLOSA, warnings and bicycle telemetry independently of OTM. | Source complete; offline device test gate |
| APP-009 | Direct Flutter/ADB/Xcode installation workflows are documented. | External gate: install on one phone per platform |
| APP-010 | No beta service is required by the source. | Optional/Could |
| APP-011 | Advanced settings persist sensor enable/rate and send acknowledged OBU configuration commands outside the ride UI. | Source complete; S3 round-trip gate |
| APP-012 | Sensor pose editor stores timestamped position/orientation in the defined bicycle frame and session provenance. | Source complete |
| APP-013 | DBC files can be imported, hashed, persisted, enabled/disabled/removed and applied to incoming CAN records; Intel and Motorola tests exist. | Source complete; device lifecycle gate |

## Data, provenance and time

| ID | Evidence in this version | Status |
| --- | --- | --- |
| DATA-001 | `ObuDataRecord` requires source, acquisition time and distinct arrival time; phone substreams retain native times. | Source complete; embedded-stream inspection gate |
| DATA-002 | Raw, measured, OS-fused, filtered, derived, event and simulation provenance are distinct. | Source complete |
| DATA-003 | Right-handed rear-wheel-axle frame (x forward, y left, z up) is documented and embedded in pose/session metadata. | Source complete; transform validation gate |
| DATA-004 | Header records app/build, reported S3/C5 firmware, settings, poses, DBC hashes, routing provider/profile and clock state/quality. Unknown values remain explicit. | Source complete; connected-firmware provenance gate |
| DATA-005 | Every pose has `updatedAt`; the complete active settings snapshot is written at session start. | Source complete |
| TIME-001 | App preserves supplied source acquisition time separately from arrival. C5 receive-time generation is firmware-owned. | Source complete plus embedded/out of app |
| TIME-002 | GNSS PPS/UTC-to-S3 mapping is firmware-owned; session schema has a place for reported state. | Embedded/out of app |
| TIME-003 | `sensors_plus` event times and platform location times are retained on the phone timeline. Common OBU offset/uncertainty still needs measurement. | External gate |
| TIME-004 | Source sequence/session-continuity and system events expose resets when reported. C5/S3 reset emission is firmware-owned. | External gate |
| TIME-005 | Acquisition and arrival/log time are separate fields in canonical and CSV records. | Source complete |
| TIME-006 | Session provenance accepts correlation quality, but measured C5↔S3 alignment is firmware/test-rig work. | Embedded/out of app |
| TIME-007 | Timing state belongs in header/events; loss/recovery events must be emitted by connected firmware. | External gate |

## Scientific logging (LOG)

| ID | Evidence in this version | Status |
| --- | --- | --- |
| LOG-001 | Streaming writes use `IOSink` and avoid in-memory session accumulation. | External gate: representative four-hour endurance/integrity test |
| LOG-002 | One JSONL session contains header provenance, OBU snapshots, raw records, phone sensors, warning/GLOSA state, diagnostics and events. Q-003 remains open, so JSONL is provisional rather than a design freeze. | Source complete, provisional format |
| LOG-003 | PCAPNG exporter emits raw V2X frames in acquisition order using link type 105. | Source complete; Wireshark validation gate |
| LOG-004 | CSV exporter retains times, source, origin, provenance, sequence, decoded JSON and raw base64. | Source complete; Python/MATLAB import gate |
| LOG-005 | JSONL, CSV and PCAPNG share the same canonical stored session. | Source complete |
| LOG-006 | Replay supports 1×, pause/resume, seek and accelerated playback. C-ITS raw-record payloads run through the same stateful decode/GLOSA/DENM-warning processor as live data. | Source complete; deterministic equivalence gate |
| LOG-007 | Replay records are marked `replay`; OTM checks both replay activity and live origin. No V2X replay-transmit path exists. | Source complete |
| LOG-008 | Records retain sequence; diagnostics events retain gap, overflow and continuity counters. | Source complete; loss-injection gate |
| LOG-009 | UTC/native acquisition times and arrival times support external-video alignment. | Source complete; synchronization demonstration gate |
| LOG-010 | Canonical research recording is phone-side; no complete S3 microSD database is required. | Source complete architecture |
| LOG-011 | S3 diagnostic rotation/retention is firmware-owned. | Embedded/out of app |
| LOG-012 | App logs transport diagnostics, subsystem transitions and lifecycle gaps; firmware boot/reset/version detail must arrive from S3. | External gate |

## Navigation (NAV)

| ID | Evidence in this version | Status |
| --- | --- | --- |
| NAV-001 | Search, selection, route rendering, instructions and advancement stay inside the app. | Source complete; two-platform route test gate |
| NAV-002 | Current prototype uses Valhalla bicycle costing without a paid app subscription. | Source complete candidate |
| NAV-003 | `NavigationRoute` exposes full geometry and maneuver list to controller/algorithms. | Source complete |
| NAV-004 | No Hamburg candidate benchmark or selected baseline is bundled. `providerFrozen` is deliberately false. | Open decision/blocker (Q-001/Q-002) |
| NAV-005 | `NavigationService` isolates provider choice from OBU/BLE protocol; mock provider tests exist. | Source complete |
| NAV-006 | Network errors are navigation state only; local repositories, warnings and logging continue. | Source complete; offline integration gate |
| NAV-007 | Route geometry/maneuvers are typed data, not scraped from map UI. | Source complete |

## OpenTrafficMap (OTM)

| ID | Evidence in this version | Status |
| --- | --- | --- |
| OTM-001 | Only the phone has the MQTT client; no S3/C5 internet dependency is introduced. | Source complete; broker test gate |
| OTM-002 | Publisher sends `rawBytes` directly on `its/<node>/packet`. | Source complete; byte-for-byte broker gate |
| OTM-003 | Publish is an independent asynchronous subscriber; offline frames are counted/dropped and never block local processing. | Source complete |
| OTM-004 | TLS host, port and node ID are persistent editable settings. | Source complete |
| OTM-005 | Replay activity and record origin independently prohibit publishing. | Source complete |
| OTM-006 | Attempted/successful/failed counters and connection/error state are visible. | Source complete |
| OTM-007 | Fresh default is disabled; enabling requires an explicit disclosure/confirmation and can be reversed. | Source complete |
| OTM-008 | Publisher has no queue; an offline live frame is failed immediately and is never caught up. | Source complete |
| OTM-009 | Integration is upload-only; no OTM subscription feeds local features. | Source complete |
| OTM-010 | Current implementation uses MQTT/TLS, QoS 0, non-retained packet messages and no credentials; configuration can change with the interface. | Source complete; current-interface integration gate |

## Security and development/test

| ID | Evidence in this version | Status |
| --- | --- | --- |
| SEC-001 | BLE repository fails protected commands with `UNAUTHENTICATED_LINK` until S3 diagnostics confirm authenticated/encrypted state. | Source complete; S3 pairing/security test gate |
| SEC-002 | No app UI exposes V2X TX enable; any non-reconnect BLE command is authentication-gated. Firmware authorization remains required. | Source complete plus embedded gate |
| SEC-003 | Credential API uses `flutter_secure_storage`; ordinary non-secret settings use asynchronous preferences. OTM currently requires no credential. | Source complete |
| SEC-004 | Replaceable `CitsSecurityValidator` receives exact raw bytes and appends verification provenance without changing raw logging/transport. | Source complete; future validator absent by design |
| TEST-001 | Deterministic OBU and phone-sensor simulation plus stored-session replay drive the app without live radios/sensors. | Source complete; physical-phone test gate |
| TEST-002 | C-ITS/transport/GLOSA/DBC fixtures and replay provide deterministic injection paths; GNSS/CAN/V2X hardware injection remains rig-owned. | Source complete plus external gate |
| TEST-003 | NAV-004 and canonical-format Q-003 remain explicitly open; code exposes the routing provider as not frozen. | Source complete |

## Required acceptance runs

1. Run `tool/verify.sh` with Flutter 3.35+ and retain the analyzer/test report.
2. Decode known-valid ETSI UPER captures for every required family and compare
   structured fields plus exact raw-frame linkage.
3. Replay a defined Hamburg route/capture and verify route-to-approach-lane and
   signal-group selection, countdown and GLOSA output.
4. Build/install on one supported Android phone and iPhone; run four hours
   locked with representative V2X, GNSS, CAN, BLE-sensor and phone-sensor load.
5. Inject MTU 23/large MTU, loss, disorder, stalls, overflow, Bluetooth off,
   out-of-range, S3 reset, C5 reset and OBU power cycle.
6. Prove unauthenticated clients cannot change configuration or enable V2X TX.
7. Characterize C5↔S3↔GNSS↔phone time mapping and PPS loss/recovery.
8. Open PCAPNG in Wireshark; import CSV in Python and MATLAB; verify counts,
   order, timestamps and source identity.
9. Test current OTM endpoint with representative frames, network outage and
   replay while confirming zero catch-up/live contamination.
10. Complete Q-001/Q-002 routing benchmark and Q-003 canonical-format decision
    before either choice is marked Accepted.
