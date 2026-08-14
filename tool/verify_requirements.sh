#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

require_text() {
  expected=$1
  file=$2
  if ! grep -Fq -- "$expected" "$file"; then
    echo "Requirement invariant missing from $file: $expected" >&2
    exit 1
  fi
}

require_text "enabled: false" lib/models/app_settings.dart
require_text "origin == RecordOrigin.live" lib/models/data_record.dart
require_text "replayActive || !record.mayUploadToOtm" lib/data/otm/otm_publisher.dart
require_text "'/packet'" lib/data/otm/otm_publisher.dart
require_text "MqttQos.atMostOnce" lib/data/otm/otm_publisher.dart
require_text "DataFreshness.bufferedRecovered" lib/data/universal_ble_obu_repository.dart
require_text "outOfOrderSequences" lib/protocol/obu_protocol.dart
require_text "comfortableMaximumSpeedKmh" lib/cits/glosa_service.dart
require_text "GlosaAvailability.ambiguousAssociation" lib/cits/glosa_service.dart
require_text "GlosaAvailability.noSpatem" lib/cits/glosa_service.dart
require_text "_replayCitsProcessor" lib/state/obu_controller.dart
require_text "_citsProcessor.processMessage" lib/data/universal_ble_obu_repository.dart
require_text "WarningProvenance.standardizedDenm" lib/data/universal_ble_obu_repository.dart
require_text "WarningProvenance.inferredExperimental" lib/data/universal_ble_obu_repository.dart
require_text "UNAUTHENTICATED_LINK" lib/data/universal_ble_obu_repository.dart
require_text "abstract interface class CitsSecurityValidator" lib/cits/cits_security_validator.dart
require_text "acquisitionTime" lib/models/data_record.dart
require_text "rawBase64" lib/models/data_record.dart
require_text "rear wheel axle origin; x forward, y left, z up" lib/data/session/ride_session_manager.dart
require_text "foregroundServiceType=\"connectedDevice|location\"" android/app/src/main/AndroidManifest.xml
require_text "bluetooth-central" ios/Runner/Info.plist
require_text "Experimental safety functions are not certified" lib/screens/about_screen.dart

echo "Static requirement invariants passed."
