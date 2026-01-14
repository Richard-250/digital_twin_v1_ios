# macOS Swift Photogrammetry Server

This server uses the same Swift `PhotogrammetrySession` API as your iOS app, but runs on macOS.

## Setup

### 1. Install Swift (if not already installed)
```bash
# Check if Swift is installed
swift --version
```

### 2. Build and Run
```bash
cd ServerProcessingServer
swift build
swift run ServerProcessingServer --port 1100
```

Or use Vapor's run command:
```bash
swift run ServerProcessingServer serve --hostname 0.0.0.0 --port 1100
```

## How It Works

1. **Uses PhotogrammetrySession** - Same Swift API as iOS
2. **HTTP Server** - Receives images via POST /upload
3. **Background Processing** - Processes in async tasks
4. **Status API** - GET /status/:jobId for progress
5. **Download API** - GET /download/:jobId for results

## Requirements

- macOS 12.0+ (for PhotogrammetrySession)
- Swift 5.9+
- Vapor framework (installed via Swift Package Manager)

## Advantages Over Python CLI

- ✅ Uses same API as iOS app
- ✅ Better progress tracking
- ✅ More control over processing
- ✅ Native Swift code
- ✅ Better error handling

