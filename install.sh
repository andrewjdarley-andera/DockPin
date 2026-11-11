#!/bin/bash
# Builds DockPin from source, installs it to ~/Applications, and starts it at login.
# Safe to re-run: it replaces any existing install.
#
#   ./install.sh               build and install
#   ./install.sh --build-only  build into ./build without installing
set -euo pipefail
cd "$(dirname "$0")"

LABEL="com.user.dockpin"
APP="$HOME/Applications/DockPin.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/DockPin.log"
BUILD="build/DockPin.app"
DOMAIN="gui/$(id -u)"

if ! command -v swiftc >/dev/null; then
    echo "Swift compiler not found. Install the Xcode Command Line Tools first:"
    echo "    xcode-select --install"
    exit 1
fi

echo "==> Building DockPin"
rm -rf build
mkdir -p "$BUILD/Contents/MacOS"
swiftc -O Sources/*.swift -o "$BUILD/Contents/MacOS/DockPin"
cp Resources/Info.plist "$BUILD/Contents/Info.plist"
codesign --force --sign - "$BUILD" 2>/dev/null

if [[ "${1:-}" == "--build-only" ]]; then
    echo "Built $BUILD"
    exit 0
fi

echo "==> Installing to $APP"
if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    for _ in $(seq 1 50); do
        launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 || break
        sleep 0.1
    done
fi
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$APP"
cp -R "$BUILD" "$APP"

# A rebuilt binary has a new signature, so any earlier Accessibility grant no
# longer matches it. Clear the stale entry so macOS asks again.
tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true

cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP/Contents/MacOS/DockPin</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLIST

: > "$LOG"
echo "==> Starting DockPin"
launchctl bootstrap "$DOMAIN" "$AGENT"

echo
echo "DockPin needs Accessibility access to watch the cursor."
echo "Turn on DockPin in System Settings > Privacy & Security > Accessibility."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
printf "Waiting for permission"
for _ in $(seq 1 90); do
    if grep -q "event tap running" "$LOG" 2>/dev/null; then
        echo
        echo "DockPin is running. The Dock will now stay on your built-in display."
        echo "If the Dock is on an external display right now, push the cursor against"
        echo "the bottom of the built-in display once to bring it back."
        exit 0
    fi
    printf "."
    sleep 2
done
echo
echo "Still waiting. DockPin keeps running in the background and will start"
echo "working as soon as you grant access - no need to run this again."
