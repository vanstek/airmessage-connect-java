#!/bin/bash
# Run AirMessage Connect in local test mode (insecure + unlinked)
# This runs the server on port 1259 without SSL or Firebase authentication

cd "$(dirname "$0")"

echo "Starting AirMessage Connect in TEST MODE..."
echo "- Running WITHOUT SSL (ws:// instead of wss://)"
echo "- Running WITHOUT Firebase authentication"
echo "- Server will listen on port 1259"
echo ""
echo "Connect to: ws://localhost:1259"
echo ""
echo "Press Ctrl+C to stop the server"
echo "================================"
echo ""

java -jar build/libs/airmessage-connect.jar insecure unlinked
