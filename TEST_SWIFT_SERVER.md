# How to Test Swift Server is Listening

## Quick Test Commands

### 1. Test Health Check Endpoint (Easiest)

```bash
curl http://MacBooks-MacBook-Air.local:1100/status/test
```

**Expected Response:**
```json
{"status":"Server is running"}
```

**If it works:** ✅ Server is running and responding!

**If it fails:** Check error message:
- `Connection refused` → Server not running
- `Could not resolve host` → Hostname issue, try IP address
- `Connection timed out` → Firewall or network issue

### 2. Test with IP Address

If hostname doesn't work, find your Mac's IP and test:

```bash
# Find your Mac's IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test with IP (replace with your actual IP)
curl http://192.168.8.92:1100/status/test
```

### 3. Check if Port 1100 is Listening

```bash
lsof -i :1100
```

**Expected Output:**
```
COMMAND     PID      USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
ServerPro 40121 macbookair   12u  IPv4 ... TCP *:mctp (LISTEN)
```

**If you see this:** ✅ Server is listening on port 1100!

### 4. Check Server Process is Running

```bash
ps aux | grep ServerProcessingServer | grep -v grep
```

**Expected Output:**
```
macbookair  40121  ... ServerProcessingServer
```

**If you see this:** ✅ Server process is running!

### 5. Test from Browser

Open in your Mac's browser:
```
http://MacBooks-MacBook-Air.local:1100/status/test
```

**Expected:** JSON response: `{"status":"Server is running"}`

### 6. Test All Endpoints

```bash
# Health check
curl http://MacBooks-MacBook-Air.local:1100/status/test

# Test upload endpoint (should return error without data, but confirms endpoint exists)
curl -X POST http://MacBooks-MacBook-Air.local:1100/upload

# Test status endpoint (should return 404 for invalid job ID, but confirms endpoint exists)
curl http://MacBooks-MacBook-Air.local:1100/status/test-job-id
```

## Troubleshooting

### Server Not Responding

**Check 1: Is server running?**
```bash
ps aux | grep ServerProcessingServer | grep -v grep
```

**If nothing:** Server not running. Start it:
```bash
cd ServerProcessingServer
./START_SERVER.sh
```

**Check 2: Is port 1100 in use?**
```bash
lsof -i :1100
```

**If something else is using it:**
```bash
# Find the process
lsof -i :1100
# Kill it (replace PID with actual process ID)
kill -9 PID
```

**Check 3: Firewall blocking?**
- System Settings → Network → Firewall
- Make sure Swift/ServerProcessingServer is allowed

### Hostname Not Working

**Try IP address instead:**
```bash
# Get your Mac's IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test with IP
curl http://YOUR_IP:1100/status/test
```

### Connection Refused

**Possible causes:**
1. Server not running → Start server
2. Wrong port → Check server is on 1100
3. Firewall blocking → Check firewall settings

### Connection Timed Out

**Possible causes:**
1. Different WiFi networks → Mac and iPhone must be on same WiFi
2. Firewall blocking → Allow server through firewall
3. Network issue → Check WiFi connection

## Success Indicators

✅ **Server Running:**
- `curl` returns `{"status":"Server is running"}`
- `lsof -i :1100` shows ServerProcessingServer listening
- `ps aux` shows ServerProcessingServer process

✅ **Server Working:**
- Health check responds correctly
- Can connect from iPhone app
- No connection errors

## Test from iPhone App

1. Open app on iPhone
2. Try to upload images
3. Watch server terminal for logs:
   ```
   [UPLOAD] Starting upload for job: ...
   ```

If you see these logs, server is working! ✅

## Quick Test Script

Save this as `test_server.sh`:

```bash
#!/bin/bash
echo "Testing Swift Server..."
echo ""

echo "1. Checking if server process is running..."
if ps aux | grep -q "[S]erverProcessingServer"; then
    echo "   ✅ Server process found"
else
    echo "   ❌ Server process NOT found"
    exit 1
fi

echo ""
echo "2. Checking if port 1100 is listening..."
if lsof -i :1100 | grep -q LISTEN; then
    echo "   ✅ Port 1100 is listening"
else
    echo "   ❌ Port 1100 is NOT listening"
    exit 1
fi

echo ""
echo "3. Testing health check endpoint..."
response=$(curl -s http://MacBooks-MacBook-Air.local:1100/status/test)
if [ "$response" == '{"status":"Server is running"}' ]; then
    echo "   ✅ Health check passed"
else
    echo "   ❌ Health check failed: $response"
    exit 1
fi

echo ""
echo "✅ All tests passed! Server is running correctly."
```

Make it executable and run:
```bash
chmod +x test_server.sh
./test_server.sh
```

