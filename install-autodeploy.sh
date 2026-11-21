#!/usr/bin/env bash
# Installs a macOS background job that runs ./deploy.sh whenever the scheduled
# refresh task drops new rates.json / dpa.json into ./public.
# Usage:  ./install-autodeploy.sh             install (or reinstall after moving the folder)
#         ./install-autodeploy.sh --uninstall remove it
[ -x "$0" ] || chmod a+x "$0"
set -euo pipefail

SITE="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.spikey.home-calculator-deploy"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$SITE/autodeploy.log"
RUNNER="$SITE/.autodeploy-run.sh"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$PLIST" "$RUNNER"
  echo "Auto-deploy removed."
  exit 0
fi

case "$SITE" in
  "$HOME/Downloads"*|"$HOME/Desktop"*|"$HOME/Documents"*)
    echo "This folder is in Downloads, Desktop or Documents. macOS blocks background jobs there," >&2
    echo "so auto-deploy would fail silently. Move the folder (e.g. to ~/Projects) and run this again." >&2
    exit 1 ;;
esac

[ -f "$SITE/public/rates.json" ] || { echo "Run this from the home-calculator-site folder." >&2; exit 1; }
chmod a+x "$SITE/deploy.sh"

# The runner waits so both data files finish landing, and never runs twice at once.
cat > "$RUNNER" <<EOF
#!/usr/bin/env bash
sleep 45
LOCK="$SITE/.autodeploy.lock"
mkdir "\$LOCK" 2>/dev/null || exit 0
trap 'rmdir "\$LOCK"' EXIT
echo "=== \$(date '+%Y-%m-%d %H:%M:%S') ==="
"$SITE/deploy.sh" && echo "Deploy OK" || echo "Deploy FAILED"
EOF
chmod a+x "$RUNNER"

NODE_DIR="$(dirname "$(command -v npx || echo /opt/homebrew/bin/npx)")"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$RUNNER</string></array>
  <key>WatchPaths</key><array>
    <string>$SITE/public/rates.json</string>
    <string>$SITE/public/dpa.json</string>
  </array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$NODE_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Auto-deploy installed. It runs whenever public/rates.json or public/dpa.json changes."
echo "Log: $LOG"
echo "Test it now with:  touch \"$SITE/public/rates.json\"  (then check the log in about a minute)"
