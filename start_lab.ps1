$ErrorActionPreference = "SilentlyContinue"
Write-Host "[*] Preparing rooted Android 14 emulator (emulator-5554)..."
adb -s emulator-5554 root
Start-Sleep -Seconds 2

# Reset network rules and reinstall untouched FactsDroid.apk cleanly
adb -s emulator-5554 shell "iptables -t nat -F OUTPUT"
adb -s emulator-5554 uninstall com.eightksec.factsdroid | Out-Null
adb -s emulator-5554 install "$PSScriptRoot\FactsDroid.apk"

# Deploy and start frida-server daemon
adb -s emulator-5554 push "$PSScriptRoot\frida-server-17.27.5-android-x86_64" /data/local/tmp/frida-server
adb -s emulator-5554 shell "chmod 755 /data/local/tmp/frida-server && /data/local/tmp/frida-server -D &"

# Configure ADB reverse tunnel + UID-scoped iptables redirection
adb -s emulator-5554 reverse tcp:8080 tcp:8080
adb -s emulator-5554 shell "sysctl -w net.ipv4.conf.all.route_localnet=1" | Out-Null
$uid = (adb -s emulator-5554 shell "dumpsys package com.eightksec.factsdroid | grep appId=").Trim().Split("=")[-1]
Write-Host "[+] FactsDroid Linux UID: $uid"

adb -s emulator-5554 shell "iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner --uid-owner $uid -j DNAT --to-destination 127.0.0.1:8080"
adb -s emulator-5554 shell "iptables -t nat -A OUTPUT -p tcp --dport 443 -m owner --uid-owner $uid -j DNAT --to-destination 127.0.0.1:8080"

Write-Host "`n[+] Environment ready!"
Write-Host "    1. Open FactsDroid on the emulator screen."
Write-Host "    2. Ensure mitmweb is open at http://localhost:8081/?token=facts with Intercept set to: ~s"
Read-Host "`nPress [Enter] once FactsDroid is open on the emulator to attach Frida..."

& "$PSScriptRoot\.venv\Scripts\frida.exe" -D emulator-5554 --codeshare TheDauntless/disable-flutter-tls-v1 -N com.eightksec.factsdroid
