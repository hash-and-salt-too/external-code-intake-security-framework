#!/usr/bin/env bash
# Calibration battery for the shared artifact fact collector.
#
# The recurring failure mode in this project is a check that breaks SILENTLY:
# a collector that reads nothing prints the same "no drift" as a genuinely
# clean artifact. Every case below therefore asserts an EXACT COUNT, not the
# presence of an expected string — a detector that fires once among 28 false
# alarms would pass a presence test and has done so before.
#
# Fixtures are validated before use. Two hand-built fixtures produced
# misleading results during development; each one here is checked to contain
# exactly the perturbation it claims.
#
# Run after ANY change to collect_facts or to the comparator.
#
#   scripts/tests/artifact-facts-tests.sh [/path/to/Some.app]
#
# It reads only. It installs, launches and modifies nothing.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY="$SCRIPT_DIR/verify-known-artifact.sh"
PHASE4="$SCRIPT_DIR/phase4-artifact.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
PASS_COUNT=0; FAIL_COUNT=0; SKIP_COUNT=0

pass() { printf 'PASS: %s\n' "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { printf 'FAIL: %s\n      %s\n' "$1" "$2"; FAIL_COUNT=$((FAIL_COUNT+1)); }
skip() { printf 'SKIP: %s\n      %s\n' "$1" "$2"; SKIP_COUNT=$((SKIP_COUNT+1)); }

assert_eq() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi
}

# --- pick a subject -------------------------------------------------------
# No hardcoded app: this has to keep working on a different machine.
pick_app() {
  local a team ents
  for a in "$@"; do
    [[ -d "$a" ]] || continue
    team=$(codesign -dv --verbose=4 "$a" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)
    [[ -n "$team" && "$team" != "not set" ]] || continue
    ents=$(codesign -d --entitlements - --xml "$a" 2>/dev/null | plutil -p - 2>/dev/null | grep -c '=>')
    [[ "${ents:-0}" -ge 2 ]] || continue
    printf '%s\n' "$a"; return 0
  done
  return 1
}

APP="${1:-}"
if [[ -z "$APP" ]]; then
  APP=$(pick_app /Applications/*.app) || true
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "SKIP ALL: no signed third-party .app with entitlements found."
  echo "  These tests calibrate against a REAL signed bundle on purpose."
  echo "  Pass one explicitly:  $0 /Applications/Some.app"
  exit 2
fi
echo "Subject: $APP"
echo "=================================================================="

# --- 1. the collector reads something, and reads it the same way twice ----
"$VERIFY" --record "$APP" > "$TEST_ROOT/rec1.txt" 2>/dev/null
"$VERIFY" --record "$APP" > "$TEST_ROOT/rec2.txt" 2>/dev/null
grep -v '^#' "$TEST_ROOT/rec1.txt" > "$TEST_ROOT/base.txt"

n_lines=$(grep -c . "$TEST_ROOT/base.txt")
if [[ "$n_lines" -gt 0 ]]; then pass "collector produced $n_lines fact lines"
else fail "collector produced facts" "0 lines — everything below would be vacuous"; fi

if diff -q <(grep -v '^# recorded' "$TEST_ROOT/rec1.txt") \
           <(grep -v '^# recorded' "$TEST_ROOT/rec2.txt") >/dev/null; then
  pass "collector is deterministic across runs"
else
  fail "collector is deterministic" "two runs of --record disagree"
fi

for kind in component teamid authority cdflags entitlement; do
  c=$(grep -c "^$kind	" "$TEST_ROOT/base.txt")
  if [[ "$c" -gt 0 ]]; then pass "record kind '$kind' present ($c)"
  else fail "record kind '$kind' present" "0 records — that detector is untested"; fi
done

# --- 2. N: known negative -------------------------------------------------
"$VERIFY" --baseline "$TEST_ROOT/rec1.txt" "$APP" > "$TEST_ROOT/N.out" 2>&1
assert_eq "N: unchanged bundle exits 0" "0" "$?"
assert_eq "N: unchanged bundle reports zero alarms" "0" \
          "$(grep -c '🛑' "$TEST_ROOT/N.out")"

# --- 3. P2: one entitlement removed --------------------------------------
ent_line=$(grep -n "^entitlement	" "$TEST_ROOT/rec1.txt" | head -1 | cut -d: -f1)
awk -v n="$ent_line" 'NR!=n' "$TEST_ROOT/rec1.txt" > "$TEST_ROOT/p2.txt"
# Validate the fixture before trusting what it produces.
delta=$(( $(wc -l < "$TEST_ROOT/rec1.txt") - $(wc -l < "$TEST_ROOT/p2.txt") ))
ent_delta=$(( $(grep -c '^entitlement	' "$TEST_ROOT/rec1.txt") \
            - $(grep -c '^entitlement	' "$TEST_ROOT/p2.txt") ))
if [[ "$delta" -eq 1 && "$ent_delta" -eq 1 ]]; then
  pass "P2 fixture is exactly one entitlement short"
  "$VERIFY" --baseline "$TEST_ROOT/p2.txt" "$APP" > "$TEST_ROOT/P2.out" 2>&1
  assert_eq "P2: drift exits 1" "1" "$?"
  assert_eq "P2: EXACTLY one NEW PRIVILEGE, no collateral" "1" \
            "$(grep -c 'NEW PRIVILEGE' "$TEST_ROOT/P2.out")"
  want=$(sed -n "${ent_line}p" "$TEST_ROOT/rec1.txt" | cut -f2)
  if grep -Fq "$want" "$TEST_ROOT/P2.out"; then
    pass "P2: names the entitlement that was removed"
  else
    fail "P2: names the entitlement that was removed" "not found in output"
  fi
else
  fail "P2 fixture is exactly one entitlement short" \
       "line delta $delta, entitlement delta $ent_delta — fixture is unusable"
fi

# --- 4. P3: identity altered ---------------------------------------------
team=$(grep "^teamid	" "$TEST_ROOT/rec1.txt" | head -1 | sed 's/.*|//')
if [[ -n "$team" ]]; then
  sed "s/$team/ZZZZZZZZZZ/g" "$TEST_ROOT/rec1.txt" > "$TEST_ROOT/p3.txt"
  if [[ "$(wc -l < "$TEST_ROOT/rec1.txt")" -eq "$(wc -l < "$TEST_ROOT/p3.txt")" ]] \
     && ! diff -q "$TEST_ROOT/rec1.txt" "$TEST_ROOT/p3.txt" >/dev/null; then
    pass "P3 fixture changed values without changing line count"
    "$VERIFY" --baseline "$TEST_ROOT/p3.txt" "$APP" > "$TEST_ROOT/P3.out" 2>&1
    assert_eq "P3: identity drift exits 1" "1" "$?"
    n_team=$(grep -c 'teamid' "$TEST_ROOT/P3.out")
    if [[ "$n_team" -gt 0 ]]; then pass "P3: Team ID drift reported ($n_team lines)"
    else fail "P3: Team ID drift reported" "0 teamid lines in output"; fi
  else
    fail "P3 fixture changed values without changing line count" "fixture unusable"
  fi
else
  skip "P3: identity drift" "subject has no Team ID record"
fi

# --- 5. schema-1 back-compat ---------------------------------------------
# A schema-1 baseline predates persistence records; they must be skipped with a
# warning, not reported as drift. The 6.4.1 baseline can never be re-recorded.
sed 's/(schema 2)/(schema 1)/' "$TEST_ROOT/rec1.txt" \
  | grep -v '^persistence	' | grep -v '^privileged-helper	' > "$TEST_ROOT/s1.txt"
"$VERIFY" --baseline "$TEST_ROOT/s1.txt" "$APP" > "$TEST_ROOT/S1.out" 2>&1
s1_rc=$?
if grep -q 'Baseline is schema 1' "$TEST_ROOT/S1.out"; then
  pass "schema 1: back-compat warning shown"
else
  fail "schema 1: back-compat warning shown" "no schema warning in output"
fi
assert_eq "schema 1: newer record kinds not reported as drift" "0" "$s1_rc"

# --- 6. the comparator refuses misordered input --------------------------
# comm returns nonsense rather than an error when its input is out of byte
# order, so the guard matters more than it looks.
( unset LC_ALL; . "$SCRIPT_DIR/lib/artifact-facts.sh"
  LC_ALL=en_US.UTF-8 artifact_facts_require_collation 2>/dev/null ) && guard_rc=0 || guard_rc=1
assert_eq "collation guard rejects a non-C locale" "1" "$guard_rc"

# --- 7. phase4: published hash comparison --------------------------------
ARC="$TEST_ROOT/subject.zip"
ditto -c -k --keepParent "$APP" "$ARC" 2>/dev/null
real_sha=$(shasum -a 256 "$ARC" | awk '{print $1}')
"$PHASE4" "$APP" --archive "$ARC" --published-sha256 "$real_sha" >/dev/null 2>&1
assert_eq "phase4: matching published hash exits 0" "0" "$?"
bad_sha="0${real_sha:1}"; [[ "$bad_sha" == "$real_sha" ]] && bad_sha="1${real_sha:1}"
"$PHASE4" "$APP" --archive "$ARC" --published-sha256 "$bad_sha" > "$TEST_ROOT/H.out" 2>&1
assert_eq "phase4: mismatched published hash exits 1" "1" "$?"
assert_eq "phase4: mismatch is named MISMATCH" "1" \
          "$(grep -c 'MISMATCH' "$TEST_ROOT/H.out")"
"$PHASE4" "$APP" --published-sha256 "$real_sha" >/dev/null 2>&1
assert_eq "phase4: a digest without an archive is refused" "2" "$?"

# --- 8. phase4: remote-loader detector ------------------------------------
# The detector must separate code it LOADS from a homepage link it merely
# mentions. An earlier pattern exceeded BSD grep's 255-repetition limit and
# reported a clean zero for a bundle with a CDN script tag.
FIX="$TEST_ROOT/Fixture.app"
cp -R "$APP" "$FIX" 2>/dev/null
mkdir -p "$FIX/Contents/Resources"
cat > "$FIX/Contents/Resources/ecisf-test-loader.html" <<'HTML'
<html><head>
<script src="https://cdn.test.invalid/lib.min.js"></script>
</head><body><a href="https://homepage.test.invalid/support">Support</a></body></html>
HTML
"$PHASE4" "$FIX" > "$TEST_ROOT/L.out" 2>&1
if grep -q 'FAILED its self-test' "$TEST_ROOT/L.out"; then
  fail "phase4: loader detector self-test" "the detector reported itself broken"
else
  pass "phase4: loader detector passes its own self-test"
fi
assert_eq "phase4: CDN script src is flagged as a loader" "1" \
          "$(sed -n '/referenced by a LOADER/,/further origin/p' "$TEST_ROOT/L.out" \
             | grep -c 'cdn.test.invalid')"
assert_eq "phase4: a homepage link is NOT flagged as a loader" "0" \
          "$(sed -n '/referenced by a LOADER/,/further origin/p' "$TEST_ROOT/L.out" \
             | grep -c 'homepage.test.invalid')"

# --- 9. phase4: entitlements vs reviewed source ---------------------------
mkdir -p "$TEST_ROOT/src-match" "$TEST_ROOT/src-short" "$TEST_ROOT/src-empty"
# The artifact side aggregates entitlements across EVERY component, so a
# stand-in source tree has to do the same. Built from the top-level bundle
# alone, this fixture reported nested components' entitlements as "missing
# from source" — a fixture defect that looked exactly like a real finding.
grep "^component	" "$TEST_ROOT/rec1.txt" | cut -f2 | while IFS= read -r rel; do
  safe=$(printf '%s' "$rel" | tr '/ ' '__')
  codesign -d --entitlements - --xml "$APP/$rel" 2>/dev/null \
    > "$TEST_ROOT/src-match/$safe.entitlements"
done
find "$TEST_ROOT/src-match" -name '*.entitlements' -empty -delete 2>/dev/null
ent_files=$(find "$TEST_ROOT/src-match" -name '*.entitlements' | grep -c .)
if [[ "$ent_files" -gt 0 ]]; then
  "$PHASE4" "$APP" --source "$TEST_ROOT/src-match" > "$TEST_ROOT/E1.out" 2>&1
  assert_eq "entitlement diff: matching source reports no extras" "0" \
            "$(sed -n '/vs reviewed source/,/Non-Apple/p' "$TEST_ROOT/E1.out" \
               | grep -c 'not in the reviewed source')"

  src_file=""; key=""
  for f in "$TEST_ROOT/src-match"/*.entitlements; do
    [[ -e "$f" ]] || continue
    key=$(plutil -p "$f" 2>/dev/null | sed -n 's/^ *"\([^"]*\)" => [01]$/\1/p' | head -1)
    [[ -n "$key" ]] && { src_file="$f"; break; }
  done
  if [[ -n "$key" && -n "$src_file" ]]; then
    cp "$TEST_ROOT/src-match"/*.entitlements "$TEST_ROOT/src-short/" 2>/dev/null
    # The source side is a UNION across every component, so the key has to go
    # from all of them. Deleting it from one file left it present via another
    # and the control silently failed to exercise anything.
    for f in "$TEST_ROOT/src-short"/*.entitlements; do
      [[ -e "$f" ]] || continue
      /usr/libexec/PlistBuddy -c "Delete :$key" "$f" >/dev/null 2>&1
    done
    still=$(for f in "$TEST_ROOT/src-short"/*.entitlements; do
              [[ -e "$f" ]] && plutil -p "$f" 2>/dev/null; done | grep -c "\"$key\"")
    if [[ "$still" -ne 0 ]]; then
      fail "entitlement diff: positive control fixture" \
           "'$key' survives in $still place(s); the control would prove nothing"
    else
      "$PHASE4" "$APP" --source "$TEST_ROOT/src-short" > "$TEST_ROOT/E2.out" 2>&1
      if grep -q "not in the reviewed source" "$TEST_ROOT/E2.out" \
         && grep -Fq "$key" "$TEST_ROOT/E2.out"; then
        pass "entitlement diff: names a privilege absent from source ($key)"
      else
        fail "entitlement diff: names a privilege absent from source" \
             "removed '$key' from every source file and it was not reported"
      fi
    fi
  else
    skip "entitlement diff: positive control" "no scalar entitlement key to remove"
  fi

  "$PHASE4" "$APP" --source "$TEST_ROOT/src-empty" > "$TEST_ROOT/E3.out" 2>&1
  if grep -q 'diff did NOT run' "$TEST_ROOT/E3.out"; then
    pass "entitlement diff: empty source tree refuses to look clean"
  else
    fail "entitlement diff: empty source tree refuses to look clean" \
         "a source tree with no .entitlements files produced no warning"
  fi
else
  skip "entitlement diff" "subject exposes no entitlements XML to build a fixture from"
fi

echo "=================================================================="
printf 'passed %s   failed %s   skipped %s\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]] || exit 1
echo "A green battery means the instruments can SEE a known change."
echo "It says nothing about whether any artifact is safe."
exit 0
