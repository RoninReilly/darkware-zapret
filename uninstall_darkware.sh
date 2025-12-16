#!/bin/bash
echo "Stopping Application..."
pkill -f "darkware zapret" || true

echo "Unloading LaunchDaemon..."
sudo launchctl unload /Library/LaunchDaemons/com.darkware.zapret.plist 2>/dev/null || true

echo "Stopping Service..."
sudo /opt/darkware-zapret/init.d/macos/zapret stop 2>/dev/null || true

echo "Removing Files..."
rm -rf "/Applications/darkware zapret.app"
sudo rm -rf /opt/darkware-zapret
sudo rm -f /Library/LaunchDaemons/com.darkware.zapret.plist
sudo rm -f /etc/sudoers.d/darkware-zapret

echo "Cleaning Preferences & Logs..."
defaults delete com.darkware.zapret 2>/dev/null || true
rm -f /tmp/darkware-zapret.*
rm -f /tmp/darkware_install.log

echo "✅ System Cleaned Successfully!"
