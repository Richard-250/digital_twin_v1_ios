#!/bin/bash
# Script to start the photogrammetry processing server

echo "============================================================"
echo "Starting Photogrammetry Processing Server"
echo "============================================================"
echo ""
echo "Server will be accessible at: http://192.168.1.78:1100"
echo "Make sure iPhone and Mac are on the same WiFi network"
echo ""
echo "IMPORTANT: If iPhone can't connect, check macOS Firewall:"
echo "  1. System Preferences → Security → Firewall"
echo "  2. Click 'Firewall Options'"
echo "  3. Find 'Python' and allow incoming connections"
echo "  OR: Temporarily disable firewall to test"
echo ""
echo "To stop server: Press Ctrl+C"
echo "============================================================"
echo ""

cd "$(dirname "$0")"
python3 server_processing.py




