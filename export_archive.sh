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

IPA_FILE=$(find "$EXPORT_PATH" -maxdepth 1 -name "*.ipa" | head -n 1)
if [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
    echo "================================================="
    echo "  🎉 SUCCESS! IPA exported successfully:"
    echo "  📍 $IPA_FILE"
    echo "================================================="
    open -R "$IPA_FILE"
else
    echo "❌ Export completed but IPA file not found in $EXPORT_PATH"
    exit 1
fi
