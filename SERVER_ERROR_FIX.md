# Server Error: `[Errno 2] No such file or directory: 'photogrammetry'`

## Problem

When iPhone uploads photos, server shows error:
```
Error: [Errno 2] No such file or directory: 'photogrammetry'
Failed: downloadFailed
```

## Root Cause

The **Python server** (`server_processing.py`) is trying to use the `photogrammetry` CLI tool which is **not installed** on your Mac.

## Solution: Use Swift Server Instead

The **Swift server** uses `PhotogrammetrySession` directly (same API as iOS) - **NO CLI tool needed!**

### Quick Fix

1. **Stop Python server:**
   ```bash
   killall Python
   ```

2. **Start Swift server:**
   ```bash
   cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios/ServerProcessingServer
   swift build
   swift run ServerProcessingServer
   ```

3. **Verify it's running:**
   ```bash
   curl http://192.168.1.65:1100/status/test
   ```
   Should return: `Server is running`

4. **Try iPhone upload again**

---

## Alternative: Fix Python Server (Not Recommended)

If you want to use Python server, you need to install the `photogrammetry` CLI tool, which is not easily available. The Swift server is the recommended solution.

---

## Why Swift Server is Better

✅ **No CLI tool needed** - Uses PhotogrammetrySession API directly  
✅ **Same code as iOS** - Uses the same Swift API  
✅ **Better error handling** - Native Swift code  
✅ **Better progress tracking** - Direct access to session outputs  

---

## Current Status

| Item | Status |
|------|--------|
| **Python server** | ❌ Fails - Missing CLI tool |
| **Swift server** | ✅ Ready to use (needs to be started) |
| **iPhone app** | ✅ Configured correctly |
| **Server IP** | ✅ 192.168.1.65:1100 |
| **ATS fixed** | ✅ Info.plist updated |

---

## Next Steps

1. **Stop any running Python servers:**
   ```bash
   killall Python
   ```

2. **Start Swift server:**
   ```bash
   cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios/ServerProcessingServer
   swift run ServerProcessingServer
   ```

3. **In another terminal, test:**
   ```bash
   curl http://192.168.1.65:1100/status/test
   ```

4. **Try iPhone upload again**

---

## If Swift Server Has Issues

If the Swift server doesn't start properly, check:
1. Swift version: `swift --version` (need 5.9+)
2. macOS version: `sw_vers` (need macOS 12.0+)
3. Xcode installed and command line tools: `xcode-select --install`

The Swift server should work out of the box on macOS 12+ with Xcode installed.




