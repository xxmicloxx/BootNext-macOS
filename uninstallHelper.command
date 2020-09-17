#!/bin/sh

sudo launchctl stop com.xxmicloxx.BootNextHelper
sudo launchctl remove com.xxmicloxx.BootNextHelper

sudo rm -f /Library/LaunchDaemons/com.xxmicloxx.BootNextHelper.plist
sudo rm -f /Library/PrivilegedHelperTools/com.xxmicloxx.BootNextHelper

echo "Uninstalled boot helper"
