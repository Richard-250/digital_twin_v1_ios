# Switch from Python to Swift Server - Step by Step

## ✅ Python Server Stopped

The Python server has been stopped. Now let's start the Swift server.

## Step 1: Start Swift Server

Open a **NEW terminal window** and run:

```bash
cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios/ServerProcessingServer
./START_SERVER.sh
```

**Expected Output:**
```
============================================================
Starting Swift Photogrammetry Processing Server
============================================================
Server is running on port 1100

Access from iPhone using ONE of these:
  • IP Address:    http://192.168.8.92:1100
  • Hostname:      http://MacBooks-MacBook-Air.local:1100  (RECOMMENDED)

IMPORTANT:
  • iPhone and Mac must be on same WiFi network
  • Use the hostname (.local) if possible - it never changes!
============================================================
```

## Step 2: Verify Swift Server is Running

In another terminal, test the connection:

```bash
curl http://MacBooks-MacBook-Air.local:1100/status/test
```

Should return: `{"status":"Server is running"}`

## Step 3: Rebuild iPhone App

**IMPORTANT**: You must rebuild the app in Xcode:

1. Open Xcode
2. **Product → Clean Build Folder** (Shift + Cmd + K)
3. **Product → Build** (Cmd + B)  
4. **Product → Run** (Cmd + R)

## Step 4: Test Upload

1. Open the app on iPhone
2. Capture some images
3. Start processing
4. Watch the Swift server terminal for logs:
   - `[UPLOAD] Starting upload for job: ...`
   - `[PROCESSING] Starting processing for job ...`
   - `[PROCESSING] Progress: X%`

## How to Tell Which Server is Running

### Python Server (OLD - Don't Use)
- Logs look like: `192.168.8.92 - - [24/Jan/2026 00:54:10] "GET /status/test HTTP/1.1" 200 -`
- Shows "photogrammetry CLI tool not installed" error
- Uses Flask framework

### Swift Server (NEW - Use This) ✅
- Logs look like: `[UPLOAD] Starting upload for job: ...`
- Shows `[PROCESSING]` messages
- Uses PhotogrammetrySession API
- **NO CLI tool needed!**

## Troubleshooting

### Swift Server Won't Start

**Error**: "swift: command not found"
```bash
# Check Swift is installed
swift --version
# Should show Swift 5.9 or later
```

**Error**: Build fails
```bash
cd ServerProcessingServer
swift build
# Check for specific errors
```

### Still Getting "CLI tool not installed" Error

This means you're still connected to Python server:
1. **Check Python is stopped**: `ps aux | grep python | grep server_processing`
2. **Should return nothing** (no Python processes)
3. **Start Swift server** using `./START_SERVER.sh`
4. **Rebuild iPhone app** in Xcode

### Port 1100 Already in Use

```bash
# Find what's using port 1100
lsof -i :1100

# Kill the process (replace PID with actual process ID)
kill -9 PID
```

## Success Indicators

✅ **Swift Server Running**: Shows IP and hostname when starting  
✅ **No Python Processes**: `ps aux | grep python | grep server_processing` returns nothing  
✅ **Health Check Works**: `curl http://MacBooks-MacBook-Air.local:1100/status/test` returns JSON  
✅ **App Connects**: No "Cannot connect" errors  
✅ **Upload Works**: Server logs show `[UPLOAD]` messages  
✅ **Processing Works**: Server logs show `[PROCESSING]` messages  
✅ **No CLI Errors**: Should NOT see "photogrammetry CLI tool not installed"

## Next Steps

1. ✅ Python server stopped
2. ⏳ Start Swift server: `./START_SERVER.sh`
3. ⏳ Rebuild iPhone app in Xcode
4. ⏳ Test upload and processing

The Swift server uses **PhotogrammetrySession API** - no CLI tool needed! 🚀

