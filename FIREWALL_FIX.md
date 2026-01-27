# Fix: Server Connection Timeout

## Problem
iPhone can't connect to Mac server at `192.168.1.78:1100` - connection times out.

## Solution: Allow macOS Firewall

The macOS Firewall is likely blocking incoming connections on port 1100.

### Step 1: Allow Python Through Firewall

1. **Open System Preferences** (or System Settings on macOS Ventura+)
2. Go to **Security & Privacy** → **Firewall**
3. If firewall is OFF, you can turn it ON (recommended)
4. Click **Firewall Options...** (or **Options...**)
5. Find **Python** in the list
6. Set it to **Allow incoming connections**
7. Click **OK**

### Step 2: Alternative - Allow Port 1100 Manually

If Python is not in the list, you can manually allow the port:

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/bin/python3
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/bin/python3
```

### Step 3: Temporary Test - Disable Firewall

**For testing only** (not recommended for production):

1. System Preferences → Security → Firewall
2. Turn firewall OFF temporarily
3. Test if iPhone can connect
4. **Remember to turn it back ON after testing!**

---

## Step 4: Start the Server

After fixing firewall, start the server:

```bash
cd /Users/macbookair/Documents/coding/digital_twin/digital_twin_v1_ios
./start_server.sh
```

Or manually:
```bash
python3 server_processing.py
```

You should see:
```
Starting photogrammetry processing server on THIS COMPUTER
Server will be accessible at: http://192.168.1.78:1100
...
 * Running on http://0.0.0.0:1100
```

---

## Step 5: Test Connection

From Mac terminal:
```bash
curl http://192.168.1.78:1100/status/test
```

Should return: `{"status": "Server is running"}`

From iPhone app:
- The app will automatically test connection
- Should show "Server connection successful"

---

## Troubleshooting

### Still can't connect?

1. **Check server is running:**
   ```bash
   lsof -i :1100
   ```
   Should show Python process

2. **Check IP address:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Should show `192.168.1.78`. If different, update `ServerProcessingService.swift`

3. **Check both devices on same WiFi:**
   - Mac: System Preferences → Network (check WiFi network name)
   - iPhone: Settings → Wi-Fi (should show same network name)

4. **Try localhost test:**
   ```bash
   curl http://127.0.0.1:1100/status/test
   ```
   If this works but `192.168.1.78` doesn't → firewall issue

5. **Restart server:**
   ```bash
   killall Python
   python3 server_processing.py
   ```

---

## Summary

✅ **Firewall is the most common issue**
- Allow Python through firewall OR
- Temporarily disable firewall for testing

✅ **Server must be running**
- Run `./start_server.sh` or `python3 server_processing.py`

✅ **Same WiFi network**
- Mac and iPhone must be on same WiFi

✅ **Correct IP address**
- Currently: `192.168.1.78` (update if different)






