#!/usr/bin/env bash
# Calibration battery for scripts/phase5-kit/00-calibrate.sh.
#
# Meta-testing: this suite checks the script whose whole job is checking that
# other instruments are not silently blind. If it were broken it would report
# every instrument as fine, which is the failure mode it exists to prevent.
#
# Offline. Writes only inside a temporary directory, never $HOME and never
# /Users/Shared, so running the suite cannot disturb a real Phase 5 account.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUT="$SCRIPT_DIR/../phase5-kit/00-calibrate.sh"
[[ -x "$SUT" ]] || { echo "Not executable: $SUT" >&2; exit 2; }

WORK=$(mktemp -d) || { echo "Could not create a temporary directory." >&2; exit 2; }
SRV_PID=""
trap 'rm -rf "$WORK"; [[ -n "$SRV_PID" ]] && kill "$SRV_PID" 2>/dev/null' EXIT

PASSED=0; FAILED=0
ok()  { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
bad() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED+1)); }
is()  { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
has() { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else bad "$1 (missing '$3')"; fi; }
hasnt(){ if printf '%s' "$2" | grep -q -- "$3"; then bad "$1 (unexpectedly found '$3')"; else ok "$1"; fi; }

K="$WORK/kit"

# --- Argument handling -----------------------------------------------------
"$SUT" --help >/dev/null 2>&1
is "--help exits 0" "0" "$?"
"$SUT" --bogus >/dev/null 2>&1
is "an unknown flag exits 2" "2" "$?"
"$SUT" --listener-port abc --kit-root "$K" >/dev/null 2>&1
is "a non-numeric listener port exits 2" "2" "$?"

# --- Full run (from whatever account the suite runs in) --------------------
OUT=$("$SUT" --kit-root "$K" 2>&1); RC=$?

# --- Canary detectability: the check the Phase 5 finding depended on -------
has "plaintext canary positive control runs"  "$OUT" 'positive control: a plaintext canary is found'
has "base64 canary positive control runs"     "$OUT" 'positive control: a base64-encoded canary is found'
has "canary negative control runs"            "$OUT" 'negative control: a string never written is not found'
hasnt "no canary control reports a failure"   "$OUT" 'positive control FAILED'

# --- It must never claim an instrument works without evidence --------------
has "the unified log is proved end-to-end, not version-checked" "$OUT" 'marker'
has "extension enumeration is counted, not assumed"             "$OUT" 'pluginkit'
has "the qlmanage trap is called out by name"                   "$OUT" 'qlmanage -m plugins'

# --- No hardcoded shared path ----------------------------------------------
has   "the kit root given on the command line is used" "$OUT" "$K"
hasnt "no hardcoded /Users/Shared path appears"        "$OUT" '/Users/Shared/phase5-kit'

# --- Account verdict --------------------------------------------------------
if id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx admin; then
  is  "an administrator account stops the run with exit 1" "1" "$RC"
  has "and says why"      "$OUT" 'IS an administrator account'
  has "and refuses to let later results stand" "$OUT" 'nothing below it matters'
else
  is  "a non-admin account is not stopped for being admin" "yes" \
      "$([[ "$RC" -ne 1 ]] && echo yes || echo no)"
fi

# --- Listener: a POSITIVE and a NEGATIVE control ----------------------------
# Only the pair is meaningful. A check that always reports "down" would pass
# the negative alone; one that always reports "up" would pass the positive.
FREE=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()' 2>/dev/null)
OUT_DOWN=$("$SUT" --kit-root "$K" --listener-port "${FREE:-49999}" 2>&1)
has "listener NEGATIVE control: a closed port is reported as nothing listening" \
    "$OUT_DOWN" 'Nothing is listening'
has "and the fix is printed"  "$OUT_DOWN" 'python3 -m http.server'

if command -v python3 >/dev/null 2>&1; then
  cat > "$WORK/stub.py" <<'PY'
import http.server, socketserver, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(404)
        self.send_header("Content-Length", "0")
        self.end_headers()
    def log_message(self, *a):
        pass
with socketserver.TCPServer(("127.0.0.1", 0), H) as s:
    with open(sys.argv[1], "w") as f:
        f.write(str(s.server_address[1]))
    s.serve_forever()
PY
  python3 "$WORK/stub.py" "$WORK/port.txt" >/dev/null 2>&1 &
  SRV_PID=$!
  PORT=""
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    PORT=$(tr -d '\n ' < "$WORK/port.txt" 2>/dev/null)
    [[ -n "$PORT" ]] && break
    sleep 0.2
  done
  if [[ -n "$PORT" ]]; then
    OUT_UP=$("$SUT" --kit-root "$K" --listener-port "$PORT" 2>&1)
    has "listener POSITIVE control: a live listener is detected" "$OUT_UP" 'Listener answered with HTTP'
    has "a 404 is explained as correct, not as a failure"        "$OUT_UP" '404 is CORRECT'
    hasnt "a live listener is not reported as down"              "$OUT_UP" 'Nothing is listening'
  else
    bad "stub listener did not start — 3 assertions did NOT run"
  fi
else
  bad "python3 unavailable — 3 listener assertions did NOT run"
fi

# --- Kit root location reporting -------------------------------------------
# A relative path must be resolved before it is compared against $HOME, or a
# directory inside your home gets reported as readable from another account.
# Asserting on the resolved path avoids writing anything into $HOME to prove it.
mkdir -p "$WORK/rel"
OUT_ABS=$("$SUT" --kit-root "$WORK/rel" 2>&1)
has "a kit root outside home is named as cross-account readable" \
    "$OUT_ABS" 'readable across accounts'

OUT_REL=$( cd "$WORK" && "$SUT" --kit-root relkit 2>&1 )
has "a relative kit root is resolved to an absolute path" "$OUT_REL" "Kit root: $WORK/relkit"
hasnt "the unresolved relative path is never reported"    "$OUT_REL" 'Kit root: relkit'

echo "=================================================================="
echo "passed $PASSED   failed $FAILED"
echo "Green means the calibrator can tell a live instrument from a dead"
echo "one. It says nothing about whether any Phase 5 environment is"
echo "correctly isolated — only a run in that account answers that."
[[ "$FAILED" -eq 0 ]]
