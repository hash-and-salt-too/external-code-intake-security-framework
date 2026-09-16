#!/bin/bash
# Phase 5 capture.
# Takes an "after" snapshot, compares it to the baseline, and gathers everything
# into the kit's out/ directory so it can be read from another account.
# Installs nothing. Touches no network.

set -u

DIR=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=kit-common.sh
. "$DIR/kit-common.sh" || exit 2
kit_parse_common "$@" || exit 2
if [ "$KIT_HELP" -eq 1 ]; then
    echo "Usage: 02-capture.sh [options]"; echo; kit_common_options; exit 0
fi
kit_validate_common || exit 2

OUT=$(kit_out)
BASE="$HOME/baseline"
AFTER="$HOME/after"

kit_banner "Phase 5 capture"

if [ ! -d "$BASE" ]; then
    echo "ERROR: no baseline found at $BASE"
    echo "Run 01-setup.sh first."
    exit 1
fi

mkdir -p "$AFTER" "$OUT" 2>/dev/null

# --- "After" snapshot: same commands as the baseline -------------------------
{
    ls -la "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons
} > "$AFTER/launchagents.txt" 2>&1
osascript -e 'tell application "System Events" to get the name of every login item' \
    > "$AFTER/loginitems.txt" 2>&1
qlmanage -m plugins > "$AFTER/qlplugins.txt" 2>&1
ls -la "$HOME/Library/QuickLook" /Library/QuickLook > "$AFTER/qldirs.txt" 2>&1
shasum "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" > "$AFTER/shellrc.txt" 2>&1
launchctl list > "$AFTER/launchctl.txt" 2>&1
ls -la "$HOME/Library/Group Containers/" > "$AFTER/groupcontainers.txt" 2>&1
echo "[ok] After-snapshot captured."

# --- The persistence diff: this is the finding ------------------------------
diff -r "$BASE" "$AFTER" > "$OUT/persistence-diff.txt" 2>&1
DIFF_STATUS=$?

# --- Extra evidence ---------------------------------------------------------
# pluginkit, not qlmanage: modern Quick Look extensions are app extensions and
# do not appear in qlmanage's legacy plugin list.
pluginkit -m -p com.apple.quicklook.preview > "$OUT/quicklook-extensions.txt" 2>&1
if [ -n "$KIT_MATCH" ]; then
    pluginkit -m 2>/dev/null | grep -i -- "$KIT_MATCH" >> "$OUT/quicklook-extensions.txt" 2>&1
else
    echo "(no --match given, so no artifact-specific extension search was made)" \
        >> "$OUT/quicklook-extensions.txt"
fi
if [ -n "$KIT_GROUP" ]; then
    ls -la "$HOME/Library/Group Containers/$KIT_GROUP/" \
        > "$OUT/group-container.txt" 2>&1
    ls -la "$HOME/Library/Group Containers/$KIT_GROUP/js/" \
        >> "$OUT/group-container.txt" 2>&1
else
    ls -la "$HOME/Library/Group Containers/" > "$OUT/group-container.txt" 2>&1
fi
ls -la "$HOME/Applications/" > "$OUT/applications-folder.txt" 2>&1
cp "$HOME/probe/canaries.txt" "$OUT/canaries.txt" 2>/dev/null
rm -rf "$OUT/baseline" "$OUT/after" 2>/dev/null   # ecisf-allow: $OUT is the hardcoded kit root, never user input
cp -R "$BASE" "$OUT/baseline" 2>/dev/null
cp -R "$AFTER" "$OUT/after" 2>/dev/null

# Make sure the admin account can read what we just wrote.
# a+rX (capital X) adds execute only to directories, which is what makes them
# traversable. Plain a+r would leave the folders unreadable from outside.
chmod -R a+rX "$OUT" 2>/dev/null

echo "[ok] Evidence gathered in $OUT"
echo

echo "=============================================================="
echo " PERSISTENCE CHECK"
echo "=============================================================="
echo
if [ "$DIFF_STATUS" -eq 0 ]; then
    echo "  NO DIFFERENCES between baseline and after."
    echo "  Nothing was installed, registered, or persisted."
    echo "  This is the expected, clean result."
else
    echo "  DIFFERENCES FOUND. Read them carefully:"
    echo
    sed 's/^/    /' "$OUT/persistence-diff.txt"
    echo
    echo "  Some differences are harmless - the Quick Look plugin list SHOULD"
    echo "  now contain $KIT_SUBJECT, because you installed it."
    echo
    echo "  Anything else is a finding. In particular:"
    echo "    - a NEW launch agent or launch daemon"
    echo "    - a NEW login item"
    echo "    - a CHANGED shell startup file checksum"
    echo "  A Markdown previewer has no legitimate reason to add any of these."
fi
echo

echo "=============================================================="
echo " STILL TO DO"
echo "=============================================================="
echo
echo "  1. Save the listener window (WINDOW A) text into:"
echo "       $OUT/listener-log.txt"
echo "     This is the primary evidence. Do not skip it."
echo
echo "  2. Switch back to your admin account and say you are finished."
echo "     The assistant will read $OUT directly."
