# Switch to Swift Server - Quick Fix Guide

## The Problem

Your app is trying to connect to `http://172.20.10.7:1100` (old IP) but:
- The server is running on a different IP
- You want to use Swift server instead of Python

## Quick Fix Steps

### Step 1: Stop Python Server
Press `Ctrl+C` in the terminal where Python server is running.

### Step 2: Start Swift Server

```bash
cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios/ServerProcessingServer
./START_SERVER.sh
```

The server will show:
```
Access from iPhone using ONE of these:
  • IP Address:    http://192.168.8.92:1100
  • Hostname:      http://MacBooks-MacBook-Air.local:1100  (RECOMMENDED)
```

### Step 3: Rebuild iPhone App in Xcode

**IMPORTANT**: The app code is already updated to use `MacBooks-MacBook-Air.local:1100`, but you need to rebuild:

1. Open Xcode
2. **Product → Clean Build Folder** (Shift + Cmd + K)
3. **Product → Build** (Cmd + B)
4. **Product → Run** (Cmd + R) to deploy to iPhone

### Step 4: Test Connection

The app should now connect to `http://MacBooks-MacBook-Air.local:1100`

## If Hostname Doesn't Work

If `.local` hostname doesn't work, use the IP address shown when server starts:

1. Update `ServerProcessingService.swift` line 21:
   ```swift
   private let serverBaseURL = "http://192.168.8.92:1100"  // Use IP from server output
   ```

2. Rebuild app in Xcode

## Why Swift Server is Better

✅ Uses PhotogrammetrySession API (same as iOS)  
✅ No CLI tool needed  
✅ Native Swift code  
✅ Better error handling  
✅ More reliable

## Current Configuration

- **Server URL in code**: `http://MacBooks-MacBook-Air.local:1100`
- **Your Mac hostname**: `MacBooks-MacBook-Air.local`
- **Server port**: `1100`

The code is already correct - just rebuild the app! 🎯

