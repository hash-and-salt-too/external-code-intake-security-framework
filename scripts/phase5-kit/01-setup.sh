#!/bin/bash
# Phase 5 prep.
# Creates canary decoys, captures a "before" baseline, and writes probe files.
# Installs nothing. Touches no network. Safe to read before running.
#
# Run 00-calibrate.sh FIRST. This script assumes your instruments already work;
# calibration is what establishes that.

set -u

DIR=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=kit-common.sh
. "$DIR/kit-common.sh" || exit 2
kit_parse_common "$@" || exit 2
if [ "$KIT_HELP" -eq 1 ]; then
    echo "Usage: 01-setup.sh [options]"; echo; kit_common_options; exit 0
fi
kit_validate_common || exit 2

OUT=$(kit_out)
PROBE="$HOME/probe"
BASE="$HOME/baseline"

kit_banner "Phase 5 prep"

# --- Safety gate: refuse to run in an administrator account ------------------
if id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx admin; then
    echo "REFUSING TO RUN."
    echo
    echo "This account ($(id -un)) is an administrator."
    echo "Phase 5 must run in a standard, non-admin, disposable account."
    exit 1
fi
echo "[ok] Account '$(id -un)' is not an administrator."

# --- Refuse if anything real sits where a decoy would be written -------------
# Two decoys are written below. Guarding only one of them leaves the other to
# be overwritten in silence - the exact class of failure this kit exists to
# catch in other software. Keep this list and the writes below in step.
for real in "$HOME/.ssh/id_rsa" "$HOME/.aws/credentials"; do
    if [ -s "$real" ] && ! grep -q 'CANARY-AUDIT' "$real" 2>/dev/null; then
        echo
        echo "REFUSING TO RUN."
        echo "$real already exists and is not a canary file."
        echo "This account may contain real credentials. Stop and check."
        exit 1
    fi
done

# A missing id_rsa proves nothing on its own: modern keys are id_ed25519, so a
# real account full of credentials can pass the check above untouched.
for k in "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/id_ecdsa "$HOME"/.ssh/id_dsa; do
    if [ -s "$k" ]; then
        echo
        echo "REFUSING TO RUN."
        echo "$k exists, so this account holds real SSH credentials."
        echo "Phase 5 must run in a clean, disposable account."
        exit 1
    fi
done

mkdir -p "$PROBE" "$BASE" "$OUT" 2>/dev/null

# --- Canary decoys (fake, harmless, easy to search for) ----------------------
# Defined in kit-common.sh, so the script that PLANTS them and the script that
# SEARCHES for them cannot drift apart. Two separate copies would let the check
# hunt for a string that was never written and call that a clean result.
CANARY_SSH="$KIT_CANARY_SSH"
CANARY_AWS="$KIT_CANARY_AWS"

mkdir -p "$HOME/.ssh" "$HOME/.aws"
printf '%s\n' "$CANARY_SSH" > "$HOME/.ssh/id_rsa"
printf '%s\n' "$CANARY_AWS" > "$HOME/.aws/credentials"
chmod 600 "$HOME/.ssh/id_rsa" "$HOME/.aws/credentials"

# Base64 forms - this is how the contents would appear if embedded in a preview
B64_SSH=$(base64 -i "$HOME/.ssh/id_rsa" | tr -d '\n')
B64_AWS=$(base64 -i "$HOME/.aws/credentials" | tr -d '\n')

cat > "$PROBE/canaries.txt" <<EOF
Canary strings for this Phase 5 run
===================================

These are FAKE. They contain no real secret. Their only purpose is to be
easy to search for.

Search for the PLAIN form in listener requests and log output.
Search for the BASE64 form in rendered output. Software that embeds a file
usually base64-encodes it, so the plain words will NOT appear there even
when the read succeeded.

  fake SSH key   : $HOME/.ssh/id_rsa
     plain       : $CANARY_SSH
     base64      : $B64_SSH

  fake AWS creds : $HOME/.aws/credentials
     plain       : $CANARY_AWS
     base64      : $B64_AWS
EOF

echo "[ok] Canary decoys created (fake - no real secrets)."

# --- Work out how many '../' are needed to reach the root of the disk --------
depth=$(printf '%s\n' "$PROBE" | awk -F/ '{c=0; for(i=1;i<=NF;i++) if($i!="") c++; print c}')
UP=""
i=0
while [ "$i" -lt "$depth" ]; do
    UP="../$UP"
    i=$((i + 1))
done
echo "[ok] Probe folder is $depth levels deep; using '${UP}' to reach /"

# --- "Before" baseline, for the persistence check later ----------------------
{
    ls -la "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons
} > "$BASE/launchagents.txt" 2>&1
osascript -e 'tell application "System Events" to get the name of every login item' \
    > "$BASE/loginitems.txt" 2>&1
qlmanage -m plugins > "$BASE/qlplugins.txt" 2>&1
ls -la "$HOME/Library/QuickLook" /Library/QuickLook > "$BASE/qldirs.txt" 2>&1
shasum "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" > "$BASE/shellrc.txt" 2>&1
launchctl list > "$BASE/launchctl.txt" 2>&1
ls -la "$HOME/Library/Group Containers/" > "$BASE/groupcontainers.txt" 2>&1
echo "[ok] Baseline snapshot captured in $BASE"

# --- Probe files -------------------------------------------------------------

cat > "$PROBE/00-control.$KIT_EXT" <<'EOF'
# Control file

This is ordinary Markdown. It establishes what "normal" looks like.

Some **bold** text, some *italic* text, and a [link](https://example.com).

- a list item
- another list item

| Column A | Column B |
|----------|----------|
| one      | two      |

```python
print("a fenced code block, to exercise syntax highlighting")
```

Nothing here should cause any network request.
EOF

cat > "$PROBE/01-remote-image.$KIT_EXT" <<EOF
# Remote resource probe

Markdown-syntax image pointing at the local listener:

![remote](http://127.0.0.1:$KIT_PORT/remote-image-probe.png)

Raw HTML image pointing at the local listener:

<img src="http://127.0.0.1:$KIT_PORT/remote-html-img.png" alt="remote html">

If either request reaches the listener, previewing a file reaches the
network on its own.
EOF

cat > "$PROBE/02-traversal-benign.$KIT_EXT" <<EOF
# Path traversal probe - harmless target

Target is /etc/hosts, a public system file. Nothing sensitive.

Raw HTML image with a relative path that climbs out of this folder:

<img src="${UP}etc/hosts" alt="traversal benign">

Markdown-syntax equivalent, for comparison:

![traversal benign](${UP}etc/hosts)

Watch the log window for a refusal message such as "is not an image!".
  Message appears  -> the software refused the file. Good.
  No message       -> it accepted a non-image file.
EOF

cat > "$PROBE/03-traversal-canary.$KIT_EXT" <<'EOF'
# Path traversal probe - canary target

THE IMPORTANT ONE. Target is the fake private key one folder up.

Raw HTML image (this is the code path the source review flagged):

<img src="../.ssh/id_rsa" alt="canary">

Markdown-syntax equivalent (this path looked properly protected):

![canary](../.ssh/id_rsa)

Also try the fake AWS credentials:

<img src="../.aws/credentials" alt="canary aws">
EOF

cat > "$PROBE/04-script-probe.$KIT_EXT" <<EOF
# Script execution probe

Each of these tries to call the local listener. Whichever ones arrive tell
you what actually executes inside the preview.

A script tag - should be stripped by a tag filter:

<script>fetch('http://127.0.0.1:$KIT_PORT/script-tag-executed')</script>

An image with an onerror handler - NOT covered by a tag blocklist:

<img src="definitely-does-not-exist.png" onerror="fetch('http://127.0.0.1:$KIT_PORT/js-executed-img-onerror')">

An SVG with an onload handler - also not covered by a tag blocklist:

<svg onload="fetch('http://127.0.0.1:$KIT_PORT/js-executed-svg-onload')" width="10" height="10"></svg>

If /js-executed-img-onerror or /js-executed-svg-onload reaches the listener,
JavaScript runs inside the preview.

If /script-tag-executed arrives, the tag filter is not working either.
EOF

cat > "$PROBE/05-mermaid.$KIT_EXT" <<'EOF'
# Mermaid probe

```mermaid
graph TD
    A[Start] --> B{Does this render?}
    B -->|Yes| C[JavaScript is running]
    B -->|No| D[It is not]
```

If a diagram draws, JavaScript is executing - Mermaid cannot work without it.
EOF

cat > "$PROBE/06-math.$KIT_EXT" <<'EOF'
# Math probe

Inline math: $E = mc^2$

Block math:

$$
\int_{0}^{\infty} e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}
$$

If this renders as typeset mathematics, MathJax loaded and ran.
EOF

MALFORMED="$PROBE/07-malformed.$KIT_EXT"
printf '# Malformed input probe\n\n' > "$MALFORMED"
printf 'Invalid UTF-8 follows: ' >> "$MALFORMED"
printf '\xc3\x28\xa0\xa1\xe2\x28\xa1\xf0\x28\x8c\xbc' >> "$MALFORMED"
printf '\n\nTruncated table:\n\n| a | b\n|---\n| 1 \n\n' >> "$MALFORMED"
python3 - "$MALFORMED" <<'PYEOF'
import sys
with open(sys.argv[1], "a") as f:
    f.write("Deeply nested emphasis:\n\n")
    f.write("*" * 500 + "text" + "*" * 500 + "\n\n")
    f.write("Deeply nested blockquote:\n\n")
    f.write("> " * 300 + "deep\n")
PYEOF

python3 - "$PROBE/08-large.$KIT_EXT" <<'PYEOF'
import sys
with open(sys.argv[1], "w") as f:
    f.write("# Large input probe\n\n")
    for i in range(40000):
        f.write("Paragraph %d with some filler text to make this file large.\n\n" % i)
PYEOF

echo "[ok] Probe files written to $PROBE"
echo

echo "=============================================================="
echo " READY"
echo "=============================================================="
echo
echo "Probe folder : $PROBE"
ls -1 "$PROBE"
echo
echo "Canary strings are recorded in: $PROBE/canaries.txt"
echo
echo "Next: install $KIT_SUBJECT into ~/Applications, NOT /Applications,"
echo "then preview the probe files one at a time and watch your instruments."
