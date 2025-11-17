#!/usr/bin/env python3
"""
Simple test client for AirMessage Connect WebSocket server
Tests basic connectivity to the server
"""

import asyncio
import websockets
import sys

async def test_connection(uri):
    print(f"Connecting to {uri}...")
    try:
        async with websockets.connect(uri) as websocket:
            print("✓ Connected successfully!")
            print(f"  Connection: {websocket.remote_address}")
            
            # Wait a bit to see if server sends anything
            print("\nWaiting for messages (5 seconds)...")
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                print(f"  Received: {message}")
            except asyncio.TimeoutError:
                print("  (No immediate messages received)")
            
            print("\n✓ WebSocket connection is working!")
            return True
            
    except ConnectionRefusedError:
        print("✗ Connection refused - is the server running?")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

async def main():
    # Test local connection
    uri = "ws://localhost:1259"
    
    if len(sys.argv) > 1:
        uri = sys.argv[1]
    
    print("AirMessage Connect WebSocket Test")
    print("=" * 50)
    
    success = await test_connection(uri)
    
    if success:
        print("\nServer is responding correctly!")
        sys.exit(0)
    else:
        print("\nServer test failed!")
        sys.exit(1)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(1)
