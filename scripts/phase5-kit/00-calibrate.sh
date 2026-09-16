#!/bin/bash
# Phase 5 instrument calibration.
#
# Run this BEFORE 01-setup.sh, and before installing anything.
#
# Why it exists, measured rather than assumed: in this framework's worked
# example, 15 of the 24 minutes of Phase 5 preparation were spent repairing
# instruments, not auditing. `log stream` refused as admin-only, `log show`
# refused because a standard account has no log-store access, an admin-side
# live capture silently dropped every message, and `qlmanage -m plugins`
# printed nothing because it structurally cannot see a modern app extension —
# which prompted three unnecessary reinstalls.
#
# Every one of those failures produced silence, and silence reads as "clean".
# This script proves each instrument can see a KNOWN positive before you rely
# on it, and names the ones that are blind.
#
# It installs nothing, touches no external network, and writes only inside its
# own scratch directory. It is safe to run in any account: the account checks
# are REPORTED rather than enforced here, so you learn about every broken
# instrument in one pass instead of one per account switch. 01-setup.sh keeps
# the hard refusal, because that is the script that writes decoy credentials.
set -u

OK="[ok]"; BAD="[XX]"; WARN="[!!]"; INFO="[--]"

KIT_ROOT="${ECISF_KIT_ROOT:-$HOME/ecisf-phase5}"
PORT="${ECISF_LISTENER_PORT:-8000}"

usage() {
    cat <<'EOF'
Usage:
  scripts/phase5-kit/00-calibrate.sh [options]

Options:
  --kit-root <dir>   Where the kit reads and writes. Default $HOME/ecisf-phase5.
                     For CROSS-ACCOUNT evidence (isolation account writes, admin
                     account reads) pass a shared path explicitly, e.g.
                     --kit-root /Users/Shared/ecisf-phase5. That is deliberately
                     not the default: writing outside your own home should be a
                     decision, not an accident.
  --listener-port N  Port the local evidence listener is on. Default 8000.
  -h, --help         Show this message.

Exit codes (they describe findings, never approval):
  0  Every instrument proved it can see a known positive.
  1  Stop: this is an administrator account, or it holds real credentials.
  2  At least one instrument is blind. Its blind spot is named; decide
     whether to proceed without it.
EOF
}

while [ $# -gt 0 ]; do
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        --kit-root) shift; KIT_ROOT="${1:-}"; shift || true ;;
        --listener-port) shift; PORT="${1:-}"; shift || true ;;
        *) echo "$BAD Unrecognised argument: $1"; echo; usage; exit 2 ;;
    esac
done

case "$PORT" in
    ''|*[!0-9]*) echo "$BAD --listener-port must be a number, got: $PORT"; exit 2 ;;
esac

# Resolved before use: a relative path never matches the "$HOME"/* test below,
# so it would be reported as cross-account readable when it is not.
case "$KIT_ROOT" in
    /*) ;;
    *) KIT_ROOT="$(pwd)/$KIT_ROOT" ;;
esac

STOPNOW=0; BLIND=0
WORK=$(mktemp -d) || { echo "$BAD Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT

echo "=============================================================="
echo " Phase 5 - instrument calibration"
echo " Account : $(id -un)"
echo " Kit root: $KIT_ROOT"
echo " Listener: 127.0.0.1:$PORT"
echo " Date    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================================="

# --- A. Is this account actually isolated? ----------------------------------
echo
echo "--- A. Account isolation ---------------------------------------------"
if id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx admin; then
    echo "$BAD '$(id -un)' IS an administrator account."
    echo "     Phase 5 must run in a standard, disposable account. Untrusted"
    echo "     code run here can change anything on the machine."
    STOPNOW=1
else
    echo "$OK  '$(id -un)' is not an administrator."
fi

if sudo -n true >/dev/null 2>&1; then
    echo "$BAD This account can escalate with sudo without a prompt."
    STOPNOW=1
else
    echo "$OK  sudo is not available without a password."
fi

othr=0
for h in /Users/*; do
    [ -d "$h" ] || continue
    case "$h" in "$HOME"|/Users/Shared) continue ;; esac
    if ls "$h" >/dev/null 2>&1; then
        echo "$WARN Another user's home is readable from here: $h"
        othr=1
    fi
done
[ "$othr" -eq 0 ] && echo "$OK  No other user's home directory is readable."

# A missing id_rsa proves nothing: modern keys are id_ed25519, so an account
# full of real credentials can pass a naive check untouched.
realcred=0
for k in "$HOME"/.ssh/id_rsa "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/id_ecdsa \
         "$HOME"/.ssh/id_dsa "$HOME"/.aws/credentials; do
    [ -s "$k" ] || continue
    grep -q 'CANARY-AUDIT' "$k" 2>/dev/null && continue
    echo "$BAD Real credential material present: $k"
    realcred=1
done
if [ "$realcred" -eq 1 ]; then
    echo "     Phase 5 must run in a clean account holding nothing you value."
    STOPNOW=1
else
    echo "$OK  No real credential material found in the usual places."
fi

# --- B. Can this account read the unified log? ------------------------------
# End-to-end, not a version check: emit a unique marker and prove it comes back.
echo
echo "--- B. Unified log ---------------------------------------------------"
MARK="ECISF-CAL-$$-$(date +%s)"
if ! command -v log >/dev/null 2>&1; then
    echo "$BAD The 'log' command is unavailable."
    BLIND=1
else
    logger "$MARK" 2>/dev/null
    if log show --last 2m --predicate "eventMessage CONTAINS \"$MARK\"" \
         > "$WORK/log.txt" 2>"$WORK/logerr.txt" \
       && grep -q "$MARK" "$WORK/log.txt"; then
        echo "$OK  A marker written now was read back. The log is usable here."
    else
        echo "$BAD The log did NOT return a marker written seconds ago."
        if grep -qi 'not permitted\|must be\|denied' "$WORK/logerr.txt" 2>/dev/null; then
            echo "     Reason given: $(head -1 "$WORK/logerr.txt")"
        fi
        echo "     A standard account often has no log-store access at all."
        echo "     Capture from the ADMIN account instead, with log show after"
        echo "     the fact - not log stream, which drops messages silently."
        echo "     Validate that capture with a marker before trusting it."
        BLIND=1
    fi
fi

# --- C. Is the evidence listener actually listening? ------------------------
echo
echo "--- C. Local listener ------------------------------------------------"
if ! command -v curl >/dev/null 2>&1; then
    echo "$BAD curl is unavailable, so the listener cannot be calibrated."
    BLIND=1
else
    code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' \
           "http://127.0.0.1:$PORT/ecisf-calibration" 2>/dev/null)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "$BAD Nothing is listening on 127.0.0.1:$PORT (curl exit $rc)."
        echo "     Start it first, in its own window:"
        echo "         python3 -m http.server $PORT"
        echo "     The listener is the primary exfiltration oracle. Loopback is"
        echo "     normally unfiltered, so it works regardless of how the"
        echo "     firewall attributes a connection."
        BLIND=1
    else
        echo "$OK  Listener answered with HTTP $code."
        echo "     A 404 is CORRECT here - the path does not exist. What matters"
        echo "     is that the request was seen. Confirm the line"
        echo "     '/ecisf-calibration' appeared in the listener window."
    fi
fi

# --- D. Would a canary actually be found? -----------------------------------
# The Phase 5 finding in this framework's worked example turned on spotting a
# BASE64 copy of a decoy inside rendered HTML. If the search method were broken,
# "no canary found" would be indistinguishable from "nothing was stolen".
echo
echo "--- D. Canary detectability ------------------------------------------"
CANARY="CANARY-CAL-4D7E-NOT-A-REAL-SECRET"
printf '%s\n' "$CANARY" > "$WORK/plain.txt"
printf '%s' "$CANARY" | base64 | tr -d '\n' > "$WORK/encoded.txt"
B64=$(cat "$WORK/encoded.txt")
{ printf 'noise noise\n'; cat "$WORK/plain.txt"; printf 'more noise\n'; } > "$WORK/haystack-plain.txt"
{ printf 'noise noise '; cat "$WORK/encoded.txt"; printf ' more noise\n'; } > "$WORK/haystack-b64.txt"

d_ok=1
if grep -q "$CANARY" "$WORK/haystack-plain.txt"; then
    echo "$OK  positive control: a plaintext canary is found"
else
    echo "$BAD positive control FAILED: a plaintext canary was NOT found"; d_ok=0
fi
if [ -n "$B64" ] && grep -q "$B64" "$WORK/haystack-b64.txt"; then
    echo "$OK  positive control: a base64-encoded canary is found"
else
    echo "$BAD positive control FAILED: a base64 canary was NOT found"; d_ok=0
fi
if grep -q "CANARY-CAL-NEVER-WRITTEN" "$WORK/haystack-plain.txt" 2>/dev/null; then
    echo "$BAD negative control FAILED: a string never written was 'found'"; d_ok=0
else
    echo "$OK  negative control: a string never written is not found"
fi
if [ "$d_ok" -eq 1 ]; then
    echo "$INFO Search for BOTH forms in evidence. A previewer that embeds a"
    echo "     file usually base64-encodes it, so the plain words will not"
    echo "     appear in rendered output even when the theft succeeded."
else
    BLIND=1
fi

# --- E. Can you see installed extensions at all? ----------------------------
echo
echo "--- E. Extension enumeration -----------------------------------------"
if ! command -v pluginkit >/dev/null 2>&1; then
    echo "$BAD pluginkit is unavailable."
    BLIND=1
else
    n=$(pluginkit -m 2>/dev/null | grep -c .)
    if [ "${n:-0}" -gt 0 ]; then
        echo "$OK  pluginkit lists $n extension(s), so it can see this system."
    else
        echo "$BAD pluginkit returned nothing. 'Extension not registered' would"
        echo "     be indistinguishable from 'the tool cannot see'."
        BLIND=1
    fi
fi
echo "$INFO Do NOT use 'qlmanage -m plugins' to check a modern Quick Look"
echo "     extension. It lists only legacy .qlgenerator plugins and returns"
echo "     nothing for an .appex - which once caused three needless reinstalls."
echo "     Use pluginkit, or better, press space on a file and look."

# --- F. Do the snapshot commands actually work here? ------------------------
echo
echo "--- F. Snapshot commands ---------------------------------------------"
if launchctl list >/dev/null 2>&1 && [ "$(launchctl list 2>/dev/null | grep -c .)" -gt 1 ]; then
    echo "$OK  launchctl list returns data."
else
    echo "$BAD launchctl list returned nothing usable."
    BLIND=1
fi
if osascript -e 'tell application "System Events" to get the name of every login item' \
     > "$WORK/li.txt" 2>"$WORK/lierr.txt"; then
    echo "$OK  login items are readable."
else
    echo "$WARN Login items could not be read:"
    echo "     $(head -1 "$WORK/lierr.txt" 2>/dev/null)"
    echo "     This usually needs an Automation permission the first time."
    echo "     Grant it NOW, not midway through an audit."
    BLIND=1
fi

# --- G. Kit root ------------------------------------------------------------
echo
echo "--- G. Kit root ------------------------------------------------------"
if mkdir -p "$KIT_ROOT/out" 2>/dev/null && [ -w "$KIT_ROOT/out" ]; then
    echo "$OK  $KIT_ROOT/out is writable."
    case "$KIT_ROOT" in
        "$HOME"/*) echo "$INFO Inside this account's home, so the admin account will not be"
                   echo "     able to read it. For cross-account evidence re-run with"
                   echo "     --kit-root /Users/Shared/ecisf-phase5" ;;
        *) echo "$INFO Outside this account's home - readable across accounts." ;;
    esac
else
    echo "$BAD Cannot write to $KIT_ROOT/out"
    BLIND=1
fi

# --- Close ------------------------------------------------------------------
echo
echo "=============================================================="
if [ "$STOPNOW" -eq 1 ]; then
    echo " STOP. The account itself is wrong, so nothing below it matters."
    echo " Create a standard, disposable account and run this there."
    echo "=============================================================="
    exit 1
fi
if [ "$BLIND" -eq 1 ]; then
    echo " One or more instruments are BLIND, named above."
    echo " A blind instrument reports silence, and silence reads as clean."
    echo " Fix them, or write down which findings you cannot make."
    echo "=============================================================="
    exit 2
fi
echo " Every instrument saw a known positive. That means they can"
echo " detect a change - not that the software under test is safe."
echo "=============================================================="
exit 0
