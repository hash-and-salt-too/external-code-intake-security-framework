#!/usr/bin/env bash
# Calibration battery for scripts/lib/advisory-query.sh.
#
# Every assertion below exists because the opposite mistake has already been
# made in a real audit. The two that matter most are the NEGATIVE controls:
#
#   - a filter that drops everything looks identical to a clean result, so one
#     test proves records SURVIVE the filter as well as one proving they are
#     removed by it;
#   - a grouper that merges every record into one group would satisfy any test
#     that only checks "these two ended up together", so one test proves two
#     unrelated defects stay APART.
#
# Offline and deterministic: fixtures only, no network, no external code.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LIB="$SCRIPT_DIR/../lib/advisory-query.sh"
if [[ ! -r "$LIB" ]]; then
  echo "Missing library: $LIB" >&2
  exit 2
fi
# shellcheck source=../lib/advisory-query.sh
. "$LIB"

WORK=$(mktemp -d) || { echo "Could not create a temporary directory." >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

PASSED=0; FAILED=0
ok()  { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
bad() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED+1)); }
is()  { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
has() { if printf '%s' "$2" | grep -q "$3"; then ok "$1"; else bad "$1 (missing '$3')"; fi; }
hasnt() { if printf '%s' "$2" | grep -q "$3"; then bad "$1 (unexpectedly found '$3')"; else ok "$1"; fi; }

# --- Fixtures -------------------------------------------------------------
# Modelled on the real cmark-gfm picture: three Ubuntu distro records that do
# not apply to a vendored-source C library, and three upstream records of which
# two describe the SAME defect under different IDs.
cat > "$WORK/main.json" <<'EOF'
{"vulns":[
 {"id":"UBUNTU-CVE-2020-5238","affected":[{"package":{"ecosystem":"Ubuntu:20.04:LTS","name":"cmark-gfm"}}]},
 {"id":"UBUNTU-CVE-2022-24724","affected":[{"package":{"ecosystem":"Ubuntu:22.04:LTS","name":"cmark-gfm"}}]},
 {"id":"UBUNTU-CVE-2023-22485","affected":[{"package":{"ecosystem":"Ubuntu:20.04:LTS","name":"cmark-gfm"}}]},
 {"id":"CVE-2022-24724","aliases":["GHSA-mc3g-88wq-6f4x"],"affected":[{"package":{"ecosystem":"GIT","name":"github/cmark-gfm"}}]},
 {"id":"CVE-2024-22051","related":["GHSA-mc3g-88wq-6f4x"],"affected":[{"package":{"ecosystem":"GIT","name":"github/cmark-gfm"}}]},
 {"id":"CVE-2023-37463","aliases":["GHSA-r8x8-8w6q-6h6g"],"affected":[{"package":{"ecosystem":"GIT","name":"github/cmark-gfm"}}]}
]}
EOF

printf '' > "$WORK/empty.json"
printf '{"vulns":[' > "$WORK/malformed.json"
# OSV answers a no-match query with {}, not {"vulns":[]}. Both must be read as
# a valid zero, and neither may be reported as a pass.
printf '{}' > "$WORK/none.json"

cat > "$WORK/all-distro.json" <<'EOF'
{"vulns":[
 {"id":"UBUNTU-CVE-2020-5238","affected":[{"package":{"ecosystem":"Ubuntu:20.04:LTS","name":"cmark-gfm"}}]},
 {"id":"DSA-4562-1","affected":[{"package":{"ecosystem":"Debian:10","name":"cmark-gfm"}}]}
]}
EOF

# --- Fixture self-check ---------------------------------------------------
# Test fixtures lie. Assert the input really contains what the tests assume
# before trusting anything derived from it.
is "fixture: main.json holds exactly 6 records" "6" "$(jq '.vulns | length' "$WORK/main.json")"
is "fixture: 3 of them carry an Ubuntu ecosystem" "3" \
   "$(jq '[.vulns[] | select(.affected[0].package.ecosystem | startswith("Ubuntu"))] | length' "$WORK/main.json")"
is "fixture: empty.json really is zero bytes" "0" "$(wc -c < "$WORK/empty.json" | tr -d ' ')"

# --- Tooling --------------------------------------------------------------
advisory_require_tools
is "advisory_require_tools succeeds when jq is present" "0" "$?"

# --- Classification of the main fixture -----------------------------------
advisory_classify "$WORK/main.json" "$WORK/main.facts"
rc=$?
is "classify: valid response returns rc 0" "0" "$rc"

FACTS="$WORK/main.facts"
is "classify: record-total is 6"    "6" "$(advisory_fact record-total "$FACTS")"
is "classify: record-distro is 3"   "3" "$(advisory_fact record-distro "$FACTS")"
is "classify: record-upstream is 3" "3" "$(advisory_fact record-upstream "$FACTS")"
is "classify: distro records counted by ecosystem" "Ubuntu|3" \
   "$(advisory_fact distro-ecosystem "$FACTS")"

UP=$(advisory_fact upstream-id "$FACTS")
hasnt "filter NEGATIVE control: no UBUNTU- record survives" "$UP" 'UBUNTU-'
has   "filter POSITIVE control: a real upstream record does survive" "$UP" 'CVE-2022-24724'
is    "filter: exactly 3 ids survive" "3" "$(printf '%s\n' "$UP" | grep -c .)"

# --- Alias grouping -------------------------------------------------------
is "grouping: 3 distinct defects after de-duplication" "3" \
   "$(advisory_fact group-count "$FACTS")"

G_24724=$(grep '^group' "$FACTS" | grep 'CVE-2022-24724')
has "grouping POSITIVE control: CVE-2022-24724 merged with its GHSA alias" \
    "$G_24724" 'GHSA-mc3g-88wq-6f4x'

G_37463=$(grep '^group' "$FACTS" | grep 'CVE-2023-37463')
hasnt "grouping NEGATIVE control: an unrelated defect stays in its own group" \
      "$G_37463" 'CVE-2022-24724'

REL=$(grep '^related-link' "$FACTS")
has "related links are surfaced, not merged" "$REL" 'CVE-2024-22051|GHSA-mc3g-88wq-6f4x'
is  "related link did not silently collapse a group" "3" \
    "$(advisory_fact group-count "$FACTS")"

# --- Failure modes that must never look clean -----------------------------
advisory_classify "$WORK/empty.json" "$WORK/empty.facts" 2>/dev/null
is "empty response is INCONCLUSIVE, not zero advisories" "2" "$?"

advisory_classify "$WORK/malformed.json" "$WORK/malformed.facts" 2>/dev/null
is "malformed JSON is INCONCLUSIVE" "2" "$?"

advisory_classify "$WORK/none.json" "$WORK/none.facts"
rc=$?
is "a genuine no-match response {} parses" "0" "$rc"
is "a genuine no-match response reports zero records" "0" \
   "$(advisory_fact record-total "$WORK/none.facts")"

SUM_NONE=$(advisory_summary "$WORK/none.facts" "test-package")
has "zero records is explicitly NOT reported as clean" "$SUM_NONE" 'NOT a clean result'
has "zero records demands a calibration query" "$SUM_NONE" 'calibration'

advisory_classify "$WORK/all-distro.json" "$WORK/distro.facts"
is "all-distro fixture classifies" "0" "$?"
is "all-distro fixture leaves zero upstream records" "0" \
   "$(advisory_fact record-upstream "$WORK/distro.facts")"
SUM_D=$(advisory_summary "$WORK/distro.facts" "test-package")
has "everything-filtered is reported as absence of DATA, not of vulnerabilities" \
    "$SUM_D" 'absence of'

SUM_M=$(advisory_summary "$FACTS" "cmark-gfm")
has "summary warns about unmerged related cross-links" "$SUM_M" 'NOT merged automatically'
has "summary shows the distro exclusion" "$SUM_M" 'filtered as distro'

echo "=================================================================="
echo "passed $PASSED   failed $FAILED"
echo "A green battery means the classifier can SEE a known ecosystem trap"
echo "and a known duplicate. It says nothing about whether any dependency"
echo "is safe, and it never proves a zero is real — only a live calibration"
echo "query can do that."
[[ "$FAILED" -eq 0 ]]
