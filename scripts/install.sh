#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="VoiceInk"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Build first
echo "Building ${APP_NAME}..."
swift build -c release 2>&1

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

if [ ! -f "$BIN_PATH" ]; then
    echo "Error: binary not found at ${BIN_PATH}"
    exit 1
fi

# Create .app bundle
echo "Creating ${APP_NAME}.app bundle..."
mkdir -p "$MACOS_DIR"

# Copy binary
cp "$BIN_PATH" "$MACOS_DIR/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VoiceInk</string>
    <key>CFBundleIdentifier</key>
    <string>com.aulakh.voiceink</string>
    <key>CFBundleName</key>
    <string>VoiceInk</string>
    <key>CFBundleDisplayName</key>
    <string>VoiceInk</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>VoiceInk needs microphone access to record your speech for transcription.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo ""
echo "Installed: ${APP_DIR}"
echo ""
echo "To launch:"
echo "  open ${APP_DIR}"
echo ""
echo "First launch: Grant Accessibility + Microphone permissions when prompted."
