#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

./tool/verify_requirements.sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
