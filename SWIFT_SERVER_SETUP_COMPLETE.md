# Swift Server Setup - Complete Guide ✅

## ✅ Everything is Now Configured!

Your app and server are now properly set up to use the **Swift server** with **PhotogrammetrySession API** (no CLI tool needed).

## Current Configuration

### iPhone App
- **Server URL**: `http://MacBooks-MacBook-Air.local:1100`
- **Uses**: Swift server endpoints
- **Status**: Ready to connect

### Swift Server
- **Port**: `1100`
- **API**: PhotogrammetrySession (native Swift)
- **No CLI tool required** ✅
- **Endpoints**:
  - `GET /status/test` - Health check
  - `POST /upload` - Upload images
  - `GET /status/:jobId` - Check processing status
  - `GET /download/:jobId` - Download completed model

## How to Start the Swift Server

### Step 1: Stop Python Server (if running)
Press `Ctrl+C` in the terminal where Python server is running.

### Step 2: Start Swift Server

```bash
cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios/ServerProcessingServer
./START_SERVER.sh
```

The server will:
1. Build automatically if needed
2. Show the correct IP and hostname
3. Start listening on port 1100

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

### Step 3: Rebuild iPhone App in Xcode

**IMPORTANT**: The app code is already correct, but you must rebuild:

1. **Open Xcode**
2. **Product → Clean Build Folder** (Shift + Cmd + K)
3. **Product → Build** (Cmd + B)
4. **Product → Run** (Cmd + R) to deploy to iPhone

## How It Works

### 1. Upload Images
- iPhone app uploads all captured images to `/upload`
- Server receives images and creates a job
- Server returns a `jobId`

### 2. Process Images
- Server uses **PhotogrammetrySession API** (same as iOS)
- Processes images in background
- Updates progress via session outputs
- **NO CLI tool needed!** ✅

### 3. Check Status
- iPhone app polls `/status/:jobId` every 2 seconds
- Server returns current progress and stage

### 4. Download Result
- When processing completes, iPhone downloads from `/download/:jobId`
- Model is saved to iPhone and displayed

## Troubleshooting

### Server Won't Start

**Error**: Build failed
```bash
cd ServerProcessingServer
swift build
# Check for errors
```

**Error**: Port 1100 already in use
```bash
# Find what's using port 1100
lsof -i :1100
# Kill the process or use a different port
```

### App Can't Connect

**Error**: "Cannot connect to server"

1. **Check server is running**:
   ```bash
   curl http://MacBooks-MacBook-Air.local:1100/status/test
   ```
   Should return: `{"status":"Server is running"}`

2. **Check both devices on same WiFi**:
   - Mac: System Settings → Network → WiFi
   - iPhone: Settings → Wi-Fi
   - Must be the same network!

3. **Try IP address instead**:
   - Update `ServerProcessingService.swift` line 21:
   ```swift
   private let serverBaseURL = "http://192.168.8.92:1100"  // Use IP from server output
   ```
   - Rebuild app

### Processing Fails

**Error**: "photogrammetry CLI tool not installed"

This error should **NOT** appear with Swift server! If you see it:
- You're still using Python server
- Stop Python server and start Swift server
- Rebuild iPhone app

**Error**: Processing takes too long

- Normal for large image sets (100+ images)
- Check server logs for progress
- Processing happens in background

## Key Differences: Python vs Swift Server

| Feature | Python Server | Swift Server ✅ |
|---------|---------------|------------------|
| **API** | CLI tool (`photogrammetry`) | PhotogrammetrySession API |
| **Requires CLI** | ❌ Yes | ✅ No |
| **Same as iOS** | ❌ No | ✅ Yes |
| **Progress Tracking** | ⚠️ Limited | ✅ Full |
| **Error Handling** | ⚠️ Basic | ✅ Advanced |
| **Recommended** | ❌ No | ✅ **YES** |

## Verification Checklist

- [ ] Swift server is running (see output with IP/hostname)
- [ ] iPhone app rebuilt in Xcode
- [ ] Both devices on same WiFi
- [ ] Server shows: "Server is running on port 1100"
- [ ] App can connect (no "Cannot connect" error)
- [ ] Images upload successfully
- [ ] Processing starts (check server logs)
- [ ] Model downloads when complete

## Server Logs

Watch the server terminal for:
- `[UPLOAD]` - Image upload progress
- `[PROCESSING]` - Processing progress and stages
- `[DOWNLOAD]` - Download requests

## Success Indicators

✅ **Server Started**: Shows IP and hostname  
✅ **App Connected**: No connection errors  
✅ **Upload Started**: Server logs show "[UPLOAD] Starting upload"  
✅ **Processing Started**: Server logs show "[PROCESSING] Starting processing"  
✅ **Progress Updates**: Server logs show progress percentages  
✅ **Model Ready**: Server logs show "Processing completed successfully"  
✅ **Download Complete**: Model appears on iPhone

## Next Steps

1. **Start Swift server** using `./START_SERVER.sh`
2. **Rebuild iPhone app** in Xcode
3. **Test connection** from iPhone
4. **Capture images** and upload
5. **Monitor server logs** for progress
6. **Download completed model** to iPhone

Everything is configured correctly! Just start the server and rebuild the app. 🚀

