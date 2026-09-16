#!/usr/bin/env bash
# Calibration battery for scripts/phase3-defaults-vs-docs.sh.
#
# The main fixture reproduces finding 23 from this framework's worked example:
# a README claiming "by default, HTML tags are stripped" beside a source file
# setting unsafeHTMLOption = true.
#
# Two negative controls carry most of the weight:
#   - a non-security boolean must NOT be extracted, or the keyword filter is
#     doing nothing and every project would look alarming;
#   - a setting nobody documented must be reported as undocumented rather than
#     quietly dropped, because "no pairing" and "nothing to report" look
#     identical in an empty list.
#
# Offline, fixture-only. Nothing in any fixture is executed.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUT="$SCRIPT_DIR/../phase3-defaults-vs-docs.sh"
[[ -x "$SUT" ]] || { echo "Not executable: $SUT" >&2; exit 2; }

WORK=$(mktemp -d) || { echo "Could not create a temporary directory." >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

PASSED=0; FAILED=0
ok()  { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
bad() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED+1)); }
is()  { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
has() { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else bad "$1 (missing '$3')"; fi; }
hasnt(){ if printf '%s' "$2" | grep -q -- "$3"; then bad "$1 (unexpectedly found '$3')"; else ok "$1"; fi; }

# --- Fixture: finding 23, reconstructed ------------------------------------
R="$WORK/proj"; mkdir -p "$R/Sources"
cat > "$R/Sources/Settings.swift" <<'EOF'
import Foundation

class Settings {
    // Documented in the README, and the README says the opposite.
    var unsafeHTMLOption: Bool = true
    // Security-relevant and documented nowhere.
    var validateUTFOption: Bool = false
    // Not security-relevant: the keyword filter must leave this alone.
    var showLineNumbers: Bool = true
    var windowIsResizable: Bool = true
}
EOF
cat > "$R/README.md" <<'EOF'
# Example

By default, HTML tags are stripped and unsafe links are replaced by empty
strings.

Line numbering can be turned on in preferences.
EOF

# --- Fixture self-check ----------------------------------------------------
is "fixture: exactly 4 boolean declarations" "4" \
   "$(grep -c ': Bool = ' "$R/Sources/Settings.swift")"
is "fixture: exactly one 'by default' claim" "1" \
   "$(grep -ci 'by default' "$R/README.md")"

# --- Main run ---------------------------------------------------------------
OUT=$("$SUT" "$R" 2>&1); RC=$?
is "a normal run exits 0" "0" "$RC"

has "both extractors self-test before reporting" "$OUT" 'settings extractor sees a known-positive'
has "the documentation extractor self-tests too"  "$OUT" 'documentation extractor sees a known-positive'

has "the security-relevant default is extracted"  "$OUT" 'unsafeHTMLOption'
has "a second security-relevant default is extracted" "$OUT" 'validateUTFOption'
has "the documented claim is extracted"           "$OUT" 'HTML tags are stripped'

# NEGATIVE CONTROL: without this, a filter that matched everything would pass
# every assertion above while making all projects look alarming.
hasnt "a non-security boolean is NOT extracted"   "$OUT" 'showLineNumbers'
hasnt "nor is an unrelated UI boolean"            "$OUT" 'windowIsResizable'

has "the claim and the setting are paired for a human" "$OUT" 'doc:'
has "the pairing is handed to a reader, not judged"    "$OUT" 'READ THESE'
has "and it says why a guess would be wrong"           "$OUT" 'reading comprehension'

# NEGATIVE CONTROL: an undocumented default must be named, not silently absent.
has "an undocumented default is reported as undocumented" "$OUT" 'NO matching documentation claim'
UNDOC=$(printf '%s' "$OUT" | sed -n '/NO matching documentation claim/,/finding/p')
has "and validateUTFOption is the one named there" "$UNDOC" 'validateUTFOption'

# --- It must never issue a verdict -----------------------------------------
hasnt "it never claims the docs and code MATCH"    "$OUT" 'defaults match'
hasnt "it never claims a MISMATCH"                 "$OUT" 'MISMATCH'
hasnt "it never says the tree looks clean"         "$OUT" 'looks clean'

# --- Empty / unusable input must be inconclusive, never clean --------------
E="$WORK/empty"; mkdir -p "$E"
OUT_E=$("$SUT" "$E" 2>&1); RC_E=$?
is "a tree with no source exits 2" "2" "$RC_E"
has "and says so explicitly" "$OUT_E" 'absence of input, not an absence of findings'

# Source present, documentation absent: one side of the comparison is missing.
D="$WORK/nodocs"; mkdir -p "$D/Sources"
cp "$R/Sources/Settings.swift" "$D/Sources/Settings.swift"
OUT_D=$("$SUT" "$D" 2>&1); RC_D=$?
is "source without documentation exits 2" "2" "$RC_D"
has "and refuses to treat an unread README as a pass" "$OUT_D" 'not a silent pass'

# Documented vocabulary the word list does not cover.
V="$WORK/vocab"; mkdir -p "$V"
printf 'var frobnicationLevel: Bool = true\n' > "$V/a.swift"
printf 'Nothing here.\n' > "$V/README.md"
OUT_V=$("$SUT" "$V" 2>&1)
has "an empty result blames the word list, not the project" "$OUT_V" 'word list does not cover'
has "and points at how to extend it" "$OUT_V" '--keyword'

# --- Extending the word list ------------------------------------------------
OUT_K=$("$SUT" "$V" --keyword frobnication 2>&1)
has "--keyword extends the extractor" "$OUT_K" 'frobnicationLevel'
OUT_L=$("$SUT" --list-keywords 2>&1)
is "--list-keywords exits 0" "0" "$?"
has "and lists a built-in term" "$OUT_L" 'unsafe'

# --- Argument handling ------------------------------------------------------
"$SUT" >/dev/null 2>&1
is "no arguments exits 2" "2" "$?"
"$SUT" "$WORK/does-not-exist" >/dev/null 2>&1
is "a missing source tree exits 2" "2" "$?"
"$SUT" "$R" --nonsense >/dev/null 2>&1
is "an unknown flag exits 2" "2" "$?"

# --- It must never exit 1 ---------------------------------------------------
# Whether a claim and a default disagree is a judgement, so there is no
# mechanically determinable blocking fact for this check to report.
for t in "$R" "$E" "$D" "$V"; do
  "$SUT" "$t" >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 1 ]] && bad "exited 1 for $t, but this check makes no verdict"
done
ok "no fixture caused an exit code of 1"

echo "=================================================================="
echo "passed $PASSED   failed $FAILED"
echo "Green means the extractors can see a known divergence and can tell"
echo "a security-relevant default from an unrelated one. It does NOT mean"
echo "any documentation is accurate — only a reader decides that."
[[ "$FAILED" -eq 0 ]]
