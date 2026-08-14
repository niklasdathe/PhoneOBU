#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
backup_dir=$(mktemp -d)
trap 'rm -rf "$backup_dir"' EXIT INT TERM

cp "$project_root/android/app/src/main/AndroidManifest.xml" "$backup_dir/AndroidManifest.xml"
cp "$project_root/android/app/build.gradle.kts" "$backup_dir/build.gradle.kts"
cp "$project_root/android/settings.gradle.kts" "$backup_dir/settings.gradle.kts"
cp "$project_root/ios/Runner/Info.plist" "$backup_dir/Info.plist"
cp "$project_root/ios/Podfile" "$backup_dir/Podfile"
cp "$project_root/ios/Runner/AppDelegate.swift" "$backup_dir/AppDelegate.swift"
cp "$project_root/android/app/src/main/kotlin/com/niklasdathe/bicycle_obu/MainActivity.kt" "$backup_dir/MainActivity.kt"
cp "$project_root/android/app/src/main/kotlin/com/niklasdathe/bicycle_obu/RideForegroundService.kt" "$backup_dir/RideForegroundService.kt"
cp "$project_root/android/app/src/main/res/mipmap-anydpi/ic_launcher.xml" "$backup_dir/ic_launcher.xml"

cd "$project_root"
flutter create \
  --project-name bicycle_obu \
  --org com.niklasdathe \
  --platforms android,ios \
  .

cp "$backup_dir/AndroidManifest.xml" "$project_root/android/app/src/main/AndroidManifest.xml"
cp "$backup_dir/build.gradle.kts" "$project_root/android/app/build.gradle.kts"
cp "$backup_dir/settings.gradle.kts" "$project_root/android/settings.gradle.kts"
cp "$backup_dir/Info.plist" "$project_root/ios/Runner/Info.plist"
cp "$backup_dir/Podfile" "$project_root/ios/Podfile"
cp "$backup_dir/AppDelegate.swift" "$project_root/ios/Runner/AppDelegate.swift"
mkdir -p "$project_root/android/app/src/main/kotlin/com/niklasdathe/bicycle_obu"
cp "$backup_dir/MainActivity.kt" "$project_root/android/app/src/main/kotlin/com/niklasdathe/bicycle_obu/MainActivity.kt"
cp "$backup_dir/RideForegroundService.kt" "$project_root/android/app/src/main/kotlin/com/niklasdathe/bicycle_obu/RideForegroundService.kt"
mkdir -p "$project_root/android/app/src/main/res/mipmap-anydpi"
cp "$backup_dir/ic_launcher.xml" "$project_root/android/app/src/main/res/mipmap-anydpi/ic_launcher.xml"

flutter pub get
