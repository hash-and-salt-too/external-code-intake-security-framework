#!/usr/bin/env bash
# Calibration battery for scripts/phase1-provenance.sh.
#
# Every assertion is offline. The only socket touched is a closed local port,
# used to prove the most important property: that an unreachable API reports
# INCONCLUSIVE rather than producing findings about the project.
#
# Coverage limit, stated rather than papered over: the response-shape logic
# (fork-field presence, annotated-tag dereferencing, release-note scanning)
# is NOT covered here. Mocking it would need a server that can serve both
# /repos/o/n and /repos/o/n/releases, which a static file server cannot do.
# That logic is validated by a live smoke test with a known expected answer;
# see scripts/README.md.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUT="$SCRIPT_DIR/../phase1-provenance.sh"
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

DEAD='http://127.0.0.1:9'

# --- Argument handling -----------------------------------------------------
"$SUT" >/dev/null 2>&1
is "no arguments exits 2" "2" "$?"
"$SUT" notaslash --online >/dev/null 2>&1
is "a bare name without owner/repo exits 2" "2" "$?"
"$SUT" a/b/c --online >/dev/null 2>&1
is "three path segments exit 2" "2" "$?"
"$SUT" --bogus >/dev/null 2>&1
is "an unknown flag exits 2" "2" "$?"

# --- Without --online nothing is contacted ---------------------------------
OUT1=$("$SUT" someowner/somerepo 2>&1); RC1=$?
is "without --online it exits 2, not 0" "2" "$RC1"
has "it lists the requests it WOULD make" "$OUT1" '/repos/someowner/somerepo'
has "it names the owner lookup too" "$OUT1" '/users/someowner'
has "it states nothing was contacted" "$OUT1" 'Nothing was contacted'
has "and that exit 2 is not a clean result" "$OUT1" 'not a clean result'

# --- An unreachable API must never produce findings ------------------------
# This is the deadliest failure mode in the phase: a broken connection makes
# every project look like it has no releases, no contributors and no advisories.
OUT2=$(ECISF_GH_API="$DEAD" "$SUT" someowner/somerepo --online 2>&1); RC2=$?
is "an unreachable API exits 2" "2" "$RC2"
has "calibration failure is reported" "$OUT2" 'positive control FAILED'
has "it refuses to continue past a failed calibration" "$OUT2" 'Stopping rather than reporting findings'
hasnt "it never reports a repository as missing" "$OUT2" 'does not exist'
hasnt "it never reports a contributor or release count" "$OUT2" 'contributors   :'
hasnt "it never claims the project is not a fork" "$OUT2" 'this is the original'

# --- The negative control must be a real discriminator ---------------------
# A server that answers 200 to everything would make "not found" meaningless.
# Calibration has to catch that, not just an unreachable host.
if command -v python3 >/dev/null 2>&1; then
  cat > "$WORK/stub.py" <<'PY'
import http.server, socketserver, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"full_name":"octocat/Hello-World"}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
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
    OUT3=$(ECISF_GH_API="http://127.0.0.1:$PORT" "$SUT" someowner/somerepo --online 2>&1); RC3=$?
    is "an API that answers 200 to everything is caught" "2" "$RC3"
    has "the negative control names the problem" "$OUT3" 'negative control FAILED'
    has "and says 'not found' is unreliable" "$OUT3" "'Not found' is unreliable"
    hasnt "such a server never yields a positive-only pass" "$OUT3" 'negative control: a missing repository'
  else
    bad "stub server did not start — 4 assertions did NOT run"
  fi
else
  bad "python3 unavailable — 4 stub-server assertions did NOT run"
fi

# --- Response-shape logic, against a routing stub --------------------------
# A STATIC file server cannot serve both /repos/o/n and /repos/o/n/releases,
# which is why this was left untested at first. A routing stub can, so the
# logic that is easiest to get confidently wrong is covered here after all.
start_stub() { # routes-json-file -> sets PORT
  cat > "$WORK/api.py" <<'PY'
import http.server, socketserver, sys, json
routes = json.load(open(sys.argv[2]))
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        p = self.path.split("?")[0]
        entry = routes.get(p)
        if entry is None:
            status, body = 404, '{"message":"Not Found"}'
        else:
            status, body = entry[0], entry[1]
        raw = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
    def log_message(self, *a):
        pass
with socketserver.TCPServer(("127.0.0.1", 0), H) as s:
    with open(sys.argv[1], "w") as f:
        f.write(str(s.server_address[1]))
    s.serve_forever()
PY
  rm -f "$WORK/apiport.txt"
  python3 "$WORK/api.py" "$WORK/apiport.txt" "$1" >/dev/null 2>&1 &
  SRV_PID=$!
  PORT=""
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    PORT=$(tr -d '\n ' < "$WORK/apiport.txt" 2>/dev/null)
    [[ -n "$PORT" ]] && break
    sleep 0.2
  done
}

if command -v python3 >/dev/null 2>&1; then
  TAGOBJ="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  COMMIT="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  cat > "$WORK/routes.json" <<EOF
{
 "/repos/octocat/Hello-World": [200, "{\"full_name\":\"octocat/Hello-World\"}"],
 "/repos/acme/widget": [200, "{\"full_name\":\"acme/widget\",\"private\":false,\"fork\":false,\"archived\":false,\"default_branch\":\"main\",\"license\":{\"spdx_id\":\"MIT\"},\"created_at\":\"2019-01-01T00:00:00Z\",\"pushed_at\":\"2026-01-01T00:00:00Z\",\"stargazers_count\":7,\"forks_count\":1,\"open_issues_count\":2,\"has_issues\":true}"],
 "/repos/acme/forked": [200, "{\"full_name\":\"acme/forked\",\"private\":false,\"fork\":true,\"parent\":{\"full_name\":\"upstream/original\"},\"has_issues\":true}"],
 "/repos/acme/noforkfield": [200, "{\"full_name\":\"acme/noforkfield\",\"private\":false,\"has_issues\":true}"],
 "/users/acme": [200, "{\"type\":\"User\",\"created_at\":\"2012-05-05T00:00:00Z\",\"public_repos\":9}"],
 "/repos/acme/widget/releases": [200, "[]"],
 "/repos/acme/widget/contributors": [200, "[]"],
 "/repos/acme/widget/contents/.github/workflows": [200, "[]"],
 "/repos/acme/widget/security-advisories": [200, "[]"],
 "/repos/acme/widget/git/ref/tags/v1.0": [200, "{\"object\":{\"type\":\"tag\",\"sha\":\"$TAGOBJ\"}}"],
 "/repos/acme/widget/git/tags/$TAGOBJ": [200, "{\"object\":{\"sha\":\"$COMMIT\"}}"],
 "/repos/acme/widget/git/ref/tags/light": [200, "{\"object\":{\"type\":\"commit\",\"sha\":\"$COMMIT\"}}"],
 "/repos/acme/widget/releases/tags/v1.0": [200, "{\"name\":\"1.0\",\"published_at\":\"2026-02-02T00:00:00Z\",\"prerelease\":false,\"body\":\"Application is now codesigned and notarized!\"}"]
}
EOF
  start_stub "$WORK/routes.json"
  if [[ -n "$PORT" ]]; then
    API="http://127.0.0.1:$PORT"

    OUT_A=$(ECISF_GH_API="$API" "$SUT" acme/widget --online --tag v1.0 2>&1); RC_A=$?
    is "a fully-answerable repository exits 0" "0" "$RC_A"
    has "calibration passes against the stub" "$OUT_A" 'negative control: a missing repository'
    has "fork false is reported as the original" "$OUT_A" 'this is the original'
    has "licence is surfaced" "$OUT_A" 'MIT'
    has "issues-enabled is surfaced" "$OUT_A" 'issues        : enabled'

    # ANNOTATED TAG: the tag object sha is NOT the commit. Reporting the former
    # as "the commit" hands the reviewer the wrong value to clone.
    has "an annotated tag is identified as annotated" "$OUT_A" 'is ANNOTATED'
    has "the tag object sha is shown"                 "$OUT_A" "tag object   : $TAGOBJ"
    has "the DEREFERENCED commit is shown"            "$OUT_A" "commit   : $COMMIT"
    has "release notes signing claims are surfaced"   "$OUT_A" 'codesigned and notarized'
    has "and a claim is not treated as verification"  "$OUT_A" 'not verification'
    has "a missing SECURITY.md is reported absent"    "$OUT_A" 'SECURITY.md   : absent'

    OUT_L=$(ECISF_GH_API="$API" "$SUT" acme/widget --online --tag light 2>&1)
    has "a lightweight tag is identified as lightweight" "$OUT_L" 'is lightweight'
    hasnt "and is not mislabelled annotated"             "$OUT_L" 'is ANNOTATED'

    OUT_F=$(ECISF_GH_API="$API" "$SUT" acme/forked --online 2>&1)
    has "a fork is reported as a fork" "$OUT_F" 'fork          : YES'
    has "and names its parent"         "$OUT_F" 'upstream/original'
    hasnt "a fork is never called the original" "$OUT_F" 'this is the original'

    # THE load-bearing one: a missing field must not read as false.
    OUT_N=$(ECISF_GH_API="$API" "$SUT" acme/noforkfield --online 2>&1); RC_N=$?
    has "an absent fork field is reported as undetermined" "$OUT_N" 'field ABSENT'
    has "and explicitly distinguished from 'not a fork'"   "$OUT_N" "Not the same as 'not a fork'"
    hasnt "an absent fork field never reads as the original" "$OUT_N" 'this is the original'
    is "an absent fork field makes the run inconclusive" "2" "$RC_N"

    OUT_M=$(ECISF_GH_API="$API" "$SUT" acme/missing --online 2>&1); RC_M=$?
    is "a repository the API does not know exits 1" "1" "$RC_M"
    has "and names the typosquat risk" "$OUT_M" 'typosquat'

    kill "$SRV_PID" 2>/dev/null; SRV_PID=""
  else
    bad "routing stub did not start — 20 assertions did NOT run"
  fi
else
  bad "python3 unavailable — 20 response-shape assertions did NOT run"
fi

# --- No secret may reach the output ----------------------------------------
OUT4=$(ECISF_GH_API="$DEAD" GH_TOKEN=shouldnotappear "$SUT" someowner/somerepo --online 2>&1)
hasnt "a token value is never printed" "$OUT4" 'shouldnotappear'
has "the auth mode IS reported" "$OUT4" 'auth:'

echo "=================================================================="
echo "passed $PASSED   failed $FAILED"
echo "Green means the collector refuses to invent findings when it cannot"
echo "see. It says nothing about whether any project is trustworthy, and"
echo "the response-shape logic is covered by a live smoke test, not here."
[[ "$FAILED" -eq 0 ]]
