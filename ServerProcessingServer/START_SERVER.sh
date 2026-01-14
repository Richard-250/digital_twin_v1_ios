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
echo ""
echo "Server will be accessible at: http://192.168.1.65:1100"
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
    echo ""
fi

# Run server
swift run ServerProcessingServer




