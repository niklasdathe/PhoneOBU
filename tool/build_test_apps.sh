#!/usr/bin/env sh
set -eu

flutter pub get
flutter build apk --debug \
  --dart-define=OBU_TRANSPORT=demo \
  --dart-define=PHONE_SENSORS=demo

case "$(uname -s)" in
  Darwin)
    flutter build ios --debug --no-codesign \
      --dart-define=OBU_TRANSPORT=demo \
      --dart-define=PHONE_SENSORS=demo
    ;;
  *)
    echo "Skipping iOS build: Xcode requires macOS."
    ;;
esac
