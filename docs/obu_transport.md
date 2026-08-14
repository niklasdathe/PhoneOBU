# Bicycle OBU BLE transport v1

The smartphone is the BLE central/client. The ESP32-S3 is the peripheral and exposes one custom service.

## GATT profile

| Role | UUID | Properties |
| --- | --- | --- |
| OBU service | `7e570001-6f62-752d-6275-000000000001` | Primary service |
| Telemetry | `7e570002-6f62-752d-6275-000000000001` | Notify |
| Command | `7e570003-6f62-752d-6275-000000000001` | Write with response |
| Command response | `7e570004-6f62-752d-6275-000000000001` | Indicate |

The S3 should advertise the service UUID and a local name beginning with `Bicycle OBU`.

## Frame format

All multi-byte integers use little-endian byte order.

| Offset | Size | Field | Notes |
| ---: | ---: | --- | --- |
| 0 | 2 | Magic | `0xB10B` |
| 2 | 1 | Version | `1` |
| 3 | 1 | Source | phone, S3, C5, GNSS, CAN or sensor |
| 4 | 1 | Type | telemetry, C-ITS, diagnostics, command or response |
| 5 | 1 | Flags | bit 0 marks final fragment |
| 6 | 2 | Sequence | increments per source/type stream fragment |
| 8 | 2 | Message ID | common to all fragments of one record |
| 10 | 1 | Fragment index | zero based |
| 11 | 1 | Fragment count | 1–255 |
| 12 | 2 | Payload length | bytes in this fragment |
| 14 | N | Payload | UTF-8 JSON during the prototype phase |
| 14+N | 2 | CRC-16/CCITT-FALSE | calculated over header and payload |

Receivers must tolerate the default ATT MTU of 23 bytes. After the 3-byte ATT header and the 16-byte OBU frame overhead, this leaves four payload bytes per fragment. A larger negotiated MTU only increases the maximum fragment payload; it never changes the record format.

The app tracks expected sequence independently for each source/type stream,
counts forward gaps as loss, counts late/backward arrivals as out-of-order, and
keeps later valid messages decodable.

## Normalized C-ITS payloads

The v1 app accepts normalized objects with `messageSet` set to `CAM`, `VAM`
(or `VRU`), `DENM`, `MAPEM`, `SPATEM` or `IVIM`. The C5/S3 firmware may send
these normalized objects while also including the exact received frame in
`rawFrameBase64`. APP-003 still requires a production ETSI ASN.1 UPER codec and
reference-vector evidence; normalized input is not represented as that final
acceptance evidence.

Example SPATEM payload:

```json
{
  "messageSet": "SPATEM",
  "intersectionId": 127,
  "signalGroup": 3,
  "state": "permissiveMovementAllowed",
  "sourceTimestamp": "2026-08-13T12:00:00.000Z",
  "validUntil": "2026-08-13T12:00:15.000Z",
  "greenIntervals": [
    {"startsInSeconds": 0.0, "endsInSeconds": 11.4}
  ],
  "rawFrameReference": "c5-rx-004812",
  "rawFrameBase64": "..."
}
```

The phone derives GLOSA speed only after matching the SPATEM signal group to an
unambiguous, route-relevant MAPEM approach. A transported target speed is not
trusted as a GLOSA input.

## Diagnostics and recovery

Diagnostics records should include `authenticated`, `sessionContinuity`,
`recoveredRecords`, `overflowDrops`, `s3FirmwareVersion`,
`c5FirmwareVersion`, `clockSyncState`, `clockSyncQuality` and the subsystem
list. Records recovered
after an interruption must set `recovered: true`; the app then marks them
`bufferedRecovered` instead of live.

Configuration-changing commands fail closed in the app until diagnostics report
an authenticated/encrypted link. The S3 must independently enforce the same
authorization and return resulting state in every command response.

## Command acknowledgement

Each command contains a `requestId`, `command` and `arguments`. The S3 must send an indication on the response characteristic:

```json
{
  "requestId": 42,
  "ok": true,
  "code": "OK",
  "message": "Configuration stored",
  "state": {"sensorId": "wheel-speed", "rateHz": 20}
}
```

The app treats a missing response after four seconds as an explicit `TIMEOUT` failure.
