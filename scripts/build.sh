#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building VoiceInk..."
swift build -c release 2>&1

echo ""
echo "Build successful!"
echo "Binary: $(swift build -c release --show-bin-path)/VoiceInk"
