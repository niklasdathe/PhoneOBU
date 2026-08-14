#!/usr/bin/env sh
set -eu

flutter run \
  --dart-define=OBU_TRANSPORT=demo \
  --dart-define=PHONE_SENSORS=demo \
  "$@"
