#!/bin/bash
# Stops DockPin and removes everything install.sh put on this Mac.
set -uo pipefail

LABEL="com.user.dockpin"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/DockPin.app"
rm -f "$HOME/Library/Logs/DockPin.log"
tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true
echo "DockPin removed."
