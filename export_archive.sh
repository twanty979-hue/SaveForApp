#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_PATH="$PROJECT_DIR/app/build/ios/archive/Runner.xcarchive"
EXPORT_PATH="$PROJECT_DIR/app/build/ios/ipa"
PLIST_PATH="$PROJECT_DIR/app/ios/ExportOptions.plist"

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive not found at: $ARCHIVE_PATH"
    echo "👉 Please run ./build_ipa.sh first."
    exit 1
fi

echo "================================================="
echo "  🚀 Exporting SaveFor.ipa from existing archive..."
echo "================================================="

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$PLIST_PATH" \
    -allowProvisioningUpdates

if [ -f "$EXPORT_PATH/SaveFor.ipa" ]; then
    echo "================================================="
    echo "  🎉 SUCCESS! IPA exported successfully:"
    echo "  📍 $EXPORT_PATH/SaveFor.ipa"
    echo "================================================="
    open -R "$EXPORT_PATH/SaveFor.ipa"
else
    echo "❌ Export completed but SaveFor.ipa not found."
    exit 1
fi
