# VPN and Network Setup Guide

## VPN Requirements Explained

### Scenario 1: Using THIS Mac as Server (Current Setup) ✅

**Configuration:**
- Server: Your Mac at `192.168.1.78:1100`
- Client: iPhone on same WiFi network
- **VPN Required: NO** ❌

**Why:**
- Both devices are on the same local network (192.168.x.x)
- They communicate directly over WiFi, bypassing VPN
- Even if your Mac has a VPN, local network traffic doesn't go through it
- iPhone doesn't need VPN - they're on the same WiFi

**Requirements:**
1. Mac and iPhone on same WiFi network
2. Mac's IP is `192.168.1.78` (or update `ServerProcessingService.swift` if different)
3. Server running on Mac (port 1100)
4. macOS Firewall allows port 1100

---

### Scenario 2: Using REMOTE Server (Not Current Setup)

**Configuration:**
- Server: Remote server that requires VPN (e.g., `10.10.97.20`)
- Client: iPhone
- **VPN Required: YES** ✅ (ON BOTH DEVICES)

**Why:**
- Remote server is only accessible via VPN network
- iPhone MUST connect to same VPN to reach server
- Mac must also be on VPN (as server owner)

**Requirements:**
1. Both Mac and iPhone connected to same VPN
2. Server IP accessible via VPN (e.g., `10.10.97.20`)
3. Update `ServerProcessingService.swift` with VPN server IP

---

## Current Setup Summary

✅ **Using: This Mac as server (Local Network)**
- **VPN: NOT Required**
- iPhone and Mac communicate over local WiFi
- Works even if Mac has VPN (local traffic bypasses VPN)

---

## Debugger Connection Issue

The message you saw:
```
Message from debugger: lost connection
Restore the connection to "iPhone" and run "GuidedCaptureSample" again
```

**This is NOT related to server connectivity!**

**What it means:**
- Xcode lost connection to your iPhone during debugging
- This is separate from server network issues
- Common causes:
  - USB cable disconnected
  - iPhone locked/sleeping during debug
  - Xcode debugger crashed
  - Network interruption during debug build

**How to fix:**
1. **Reconnect iPhone**: Unplug and replug USB cable
2. **Trust Computer**: On iPhone, tap "Trust This Computer" if prompted
3. **Restart Debugging**: Stop and run app again in Xcode
4. **Check iPhone**: Make sure iPhone is unlocked and not sleeping
5. **Restart Xcode**: If problem persists, restart Xcode

**This is NORMAL** and happens occasionally during development. It doesn't affect your server connectivity.

---

## Testing Server Connection

### From Mac:
```bash
# Test if server is running
curl http://192.168.1.78:1100/status/test

# Should return: {"status": "Server is running"}
```

### From iPhone (in app):
- The app will automatically test connection before uploading
- If connection fails, you'll see: "Cannot connect to server at..."
- Check:
  1. Server is running on Mac
  2. Both devices on same WiFi
  3. Mac's IP is correct (192.168.1.78)

---

## Troubleshooting Network Issues

### iPhone can't connect to Mac server:

1. **Check WiFi Network:**
   ```bash
   # On Mac, check IP
   ifconfig | grep "inet " | grep -v 127.0.0.1
   
   # Should show: inet 192.168.1.78
   # If different, update ServerProcessingService.swift
   ```

2. **Check Server is Running:**
   ```bash
   # On Mac
   lsof -i :1100
   # Should show server process
   ```

3. **Check macOS Firewall:**
   - System Preferences → Security → Firewall
   - Make sure port 1100 is allowed
   - Or temporarily disable firewall to test

4. **Test Connection:**
   ```bash
   # From Mac
   curl http://192.168.1.78:1100/status/test
   ```

5. **VPN on Mac:**
   - Local network (192.168.x.x) should work even with VPN
   - If not, try disabling VPN temporarily
   - Or configure VPN to allow local network traffic

---

## Summary

| Setup | VPN Required? | Notes |
|-------|--------------|-------|
| **This Mac as server (local WiFi)** | ❌ NO | Current setup. Both devices on same WiFi. |
| **Remote server via VPN** | ✅ YES | Both Mac and iPhone need VPN. |
| **Remote server on public internet** | ❌ NO | Server must be publicly accessible. |

**Current Setup: No VPN needed!** ✅




