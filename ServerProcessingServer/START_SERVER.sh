#!/bin/bash
# Script to start the Swift photogrammetry processing server

echo "============================================================"
echo "Starting Swift Photogrammetry Processing Server"
echo "============================================================"
echo ""
echo "This server:"
echo "  ✅ Uses PhotogrammetrySession API (same as iOS)"
echo "  ✅ Processes images using native Swift code"
echo "  ✅ NO CLI tool needed!"
echo "  ✅ Uses same API as iPhone app"
echo ""
echo "The server will show the correct IP and hostname when it starts."
echo "Make sure iPhone and Mac are on the same WiFi network"
echo ""
echo "To stop server: Press Ctrl+C"
echo "============================================================"
echo ""

cd "$(dirname "$0")"

# Build if needed
if [ ! -f ".build/debug/ServerProcessingServer" ]; then
    echo "Building server..."
    swift build
    if [ $? -ne 0 ]; then
        echo "ERROR: Build failed!"
        exit 1
    fi
    echo ""
fi

# Run server
echo "Starting server..."
swift run ServerProcessingServer






