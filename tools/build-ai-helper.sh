#!/bin/bash
# Build the LifeClip Apple Intelligence helper
# Requires macOS 26+ and Xcode with Swift 6.1+

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER_DIR="$SCRIPT_DIR/lifeclip-ai-helper"

echo "Building lifeclip-ai-helper..."

if ! command -v swift &> /dev/null; then
    echo "Error: Swift toolchain not found. Install Xcode."
    exit 1
fi

cd "$HELPER_DIR"
swift build -c release 2>&1

BINARY="$HELPER_DIR/.build/release/lifeclip-ai-helper"

if [ -f "$BINARY" ]; then
    echo "Build successful: $BINARY"
    echo ""
    echo "Test availability:"
    echo "  $BINARY --check"
    echo ""
    echo "Usage:"
    echo "  echo '{\"date\":\"2026-03-13\",...}' | $BINARY"
else
    echo "Build failed: binary not found"
    exit 1
fi
