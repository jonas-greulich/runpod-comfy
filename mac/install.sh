#!/usr/bin/env bash
# Einmalig auf dem Mac ausführen (und erneut nach Änderungen an diesem Skript):
#   bash ~/PROJEKTE/runpod/runpod-comfy/mac/install.sh
# Legt comfy-pull und lora-upload nach ~/bin, richtet den Hintergrunddienst
# (launchd) für comfy-pull ein und legt den Ausgabeordner an.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="de.mogamotion.comfy-pull"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
OUT="$HOME/PROJEKTE/runpod/output"
LOG="$HOME/Library/Logs/comfy-pull.log"

chmod +x "$REPO/mac/comfy-pull" "$REPO/mac/lora-upload"

# 1. Befehle nach ~/bin
mkdir -p "$HOME/bin"
ln -sf "$REPO/mac/comfy-pull" "$HOME/bin/comfy-pull"
ln -sf "$REPO/mac/lora-upload" "$HOME/bin/lora-upload"
if ! grep -q 'HOME/bin' "$HOME/.zshrc" 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
  echo "~/bin in ~/.zshrc eingetragen (gilt ab dem nächsten Terminalfenster)"
fi

# 2. Ausgabeordner
mkdir -p "$OUT"

# 3. Hintergrunddienst
PY="$(command -v python3)"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PY</string>
    <string>-u</string>
    <string>$REPO/mac/comfy-pull</string>
    <string>--daemon</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Hintergrunddienst läuft ($LABEL), Log: $LOG"

# 4. API-Key prüfen
if security find-generic-password -s runpod -a api -w >/dev/null 2>&1; then
  echo "RunPod-API-Key im Schlüsselbund gefunden."
else
  echo
  echo "Noch kein RunPod-API-Key im Schlüsselbund. Einmalig ausführen und Key einfügen:"
  echo "  security add-generic-password -s runpod -a api -w"
  echo "Der Dienst wartet so lange und legt danach von selbst los."
fi
echo
echo "Ergebnisse landen in: $OUT/<Datum>/<Pod-Name>/"
echo "Live mitlesen: tail -f $LOG"
