# Server Processing Setup

## Overview
The app now processes photogrammetry on your server at `10.10.97.20` instead of on the iPhone.

## Server Setup (10.10.97.20)

### 1. Install Requirements
```bash
# On your macOS server
pip3 install flask
```

### 2. Run the Server
```bash
# Copy server_processing.py to your server
# Make it executable
chmod +x server_processing.py

# Run the server
python3 server_processing.py
```

The server will start on `http://0.0.0.0:1100`

### 3. Verify Server is Running
The server should respond to:
- `GET http://10.10.97.20:1100/status/test` (will return 404, but confirms server is up)

## How It Works

1. **Upload**: iPhone uploads all captured images to server
2. **Process**: Server processes images using `photogrammetry` CLI tool
3. **Poll**: iPhone polls server every 2 seconds for status
4. **Download**: When complete, iPhone downloads the USDZ model
5. **Display**: Model is shown on iPhone

## API Endpoints

- `POST /upload` - Upload images and start processing
- `GET /status/<job_id>` - Check processing status
- `GET /download/<job_id>` - Download completed model

## Notes

- Server must be macOS with `photogrammetry` CLI tool available
- Server processes jobs in background threads
- Temporary files stored in `/tmp/photogrammetry_*`
- Make sure port 1100 is accessible from your iPhone

