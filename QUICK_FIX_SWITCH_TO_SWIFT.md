# Quick Fix: Switch to Swift Server

## The Problem

You're getting this error on iPhone:
- ❌ "photogrammetry CLI tool not installed"
- ❌ Download failed

**This is because you're still using Python server!**

## The Solution: Use Swift Server ✅

Swift server uses **PhotogrammetrySession API** - **NO CLI tool needed!**

## Quick Steps

### 1. Stop Python Server

**In the terminal where Python server is running**, press:
```
Ctrl + C
```

Or kill it:
```bash
pkill -f server_processing.py
```

### 2. Start Swift Server

**Open a NEW terminal** and run:

```bash
cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios/ServerProcessingServer
./START_SERVER.sh
```

**You should see:**
```
============================================================
Starting Swift Photogrammetry Processing Server
============================================================
Server is running on port 1100

Access from iPhone using ONE of these:
  • IP Address:    http://192.168.8.92:1100
  • Hostname:      http://MacBooks-MacBook-Air.local:1100  (RECOMMENDED)
============================================================
```

### 3. Rebuild iPhone App in Xcode

**CRITICAL**: You MUST rebuild the app:

1. Open Xcode
2. **Product → Clean Build Folder** (Shift + Cmd + K)
3. **Product → Build** (Cmd + B)
4. **Product → Run** (Cmd + R)

### 4. Test

1. Open app on iPhone
2. Capture images
3. Upload to server
4. **Watch Swift server terminal** - you should see:
   ```
   [UPLOAD] Starting upload for job: ...
   [UPLOAD] Successfully received X images
   [PROCESSING] Starting processing for job ...
   [PROCESSING] Progress: 10%
   [PROCESSING] Progress: 50%
   [PROCESSING] Processing completed successfully
   ```

## How to Tell Which Server is Running

### ❌ Python Server (OLD - Wrong)
- Logs: `192.168.8.92 - - [24/Jan/2026 00:54:10] "GET /status/test HTTP/1.1" 200 -`
- Error: "photogrammetry CLI tool not installed"
- Uses Flask

### ✅ Swift Server (NEW - Correct)
- Logs: `[UPLOAD] Starting upload for job: ...`
- Logs: `[PROCESSING] Starting processing...`
- **NO CLI errors!**
- Uses PhotogrammetrySession API

## Verify Swift Server is Running

Test in terminal:
```bash
curl http://MacBooks-MacBook-Air.local:1100/status/test
```

Should return: `{"status":"Server is running"}`

## If You Still See Errors

### "Cannot connect to server"
1. Check Swift server is running (see terminal)
2. Check both devices on same WiFi
3. Try IP address instead of hostname

### "photogrammetry CLI tool not installed"
- **This means Python server is still running!**
- Stop Python: `pkill -f server_processing.py`
- Start Swift: `./START_SERVER.sh`
- Rebuild app in Xcode

### "Download failed"
- Check Swift server logs for `[PROCESSING]` messages
- Make sure processing completed: `[PROCESSING] Processing completed successfully`
- Check server logs for `[DOWNLOAD]` messages

## Summary

1. ✅ **Stop Python server** (Ctrl+C or pkill)
2. ✅ **Start Swift server** (`./START_SERVER.sh`)
3. ✅ **Rebuild iPhone app** in Xcode
4. ✅ **Test upload** - watch Swift server logs

**Swift server = NO CLI tool needed!** 🚀

