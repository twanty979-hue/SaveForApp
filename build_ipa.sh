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

if [ -f "$APP_DIR/build/ios/ipa/SaveFor.ipa" ]; then
    echo "================================================="
    echo "  🎉 SUCCESS! IPA file created successfully:"
    echo "  📍 $APP_DIR/build/ios/ipa/SaveFor.ipa"
    echo "================================================="
    open -R "$APP_DIR/build/ios/ipa/SaveFor.ipa"
else
    echo "❌ Build finished but SaveFor.ipa not found."
    exit 1
fi
