#!/bin/bash
set -e

# SaveForApp iOS IPA Build Script
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$PROJECT_DIR/app"

echo "================================================="
echo "  🚀 Starting SaveFor iOS IPA Build Process"
echo "================================================="

cd "$APP_DIR"

echo "📦 Running Flutter Build IPA (Release)..."
flutter build ipa --release --export-options-plist ios/ExportOptions.plist

IPA_FILE=$(find "$APP_DIR/build/ios/ipa" -maxdepth 1 -name "*.ipa" | head -n 1)
if [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
    echo "================================================="
    echo "  🎉 SUCCESS! IPA file created successfully:"
    echo "  📍 $IPA_FILE"
    echo "================================================="
    open -R "$IPA_FILE"
else
    echo "❌ Build finished but IPA file not found in $APP_DIR/build/ios/ipa"
    exit 1
fi
