#!/usr/bin/env bash
# ECISF shared advisory classifier.
#
# This file is SOURCED, never executed. It is the single place where a raw OSV
# response is turned into classified facts, so that a Phase 1 reputation check
# and a Phase 2 dependency check can never describe the same advisory picture
# differently.
#
# Two real misses from the QLMarkdown audit drove every design choice here:
#
#   finding 17 — three "unfixed" cmark-gfm advisories were UBUNTU-CVE records
#   describing Ubuntu's *distribution packages*. For a C library vendored as
#   source into a macOS app they do not apply at all. Without ecosystem
#   filtering this script manufactures false alarms.
#
#   finding 20 — CVE-2024-22051 is the same defect as CVE-2022-24724, re-issued
#   by a different CNA against a downstream re-packager. Counting IDs instead of
#   distinct defects inflated one bug into two.
#
# It emits FACTS. It never issues a verdict, and zero records is NOT a pass:
# a failed query also returns zero. Believe a zero only after a calibration
# query has shown the same code path can see a known positive.

ADVISORY_QUERY_SCHEMA=1

# jq is required, and no fallback is offered on purpose. plutil can read JSON,
# but it writes its parse errors to STDOUT, so a failed read would arrive
# looking exactly like data — the precise failure this file exists to prevent.
advisory_require_tools() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi
  echo "Required tool missing: jq" >&2
  echo "  jq ships with macOS 15 and later at /usr/bin/jq." >&2
  echo "  Do NOT substitute plutil: it prints parse errors to STDOUT, so an" >&2
  echo "  unreadable response would be indistinguishable from a real answer." >&2
  return 1
}

# Distro-ecosystem records describe a packaging ecosystem that a vendored-source
# dependency is not part of. They are classified and counted, never dropped
# silently, so the filtering itself stays auditable.
ADVISORY_DISTRO_ID_RE='^(UBUNTU-|DSA-|DLA-|RHSA-|RLSA-|ALSA-|SUSE-SU-|openSUSE-SU-|ALPINE-|MGASA-|PHSA-|CGA-)'

advisory_classify() {
  local in="$1" out="$2"
  : > "$out"

  if [[ ! -f "$in" ]]; then
    echo "advisory_classify: no such response file: $in" >&2
    return 2
  fi
  # The deadliest case in this whole area: a failed API call returns nothing,
  # and nothing reads as "no advisories found". An empty body is a failure.
  if [[ ! -s "$in" ]]; then
    echo "advisory_classify: response is EMPTY. The query failed; it did not" >&2
    echo "  return zero results. These are not the same thing." >&2
    return 2
  fi
  if ! jq -e . "$in" >/dev/null 2>&1; then
    echo "advisory_classify: response is not valid JSON." >&2
    return 2
  fi

  local prog
  prog='
    def distro_id: test("'"$ADVISORY_DISTRO_ID_RE"'");
    def distro_eco:
      (split(":")[0]) as $e
      | ["Ubuntu","Debian","Red Hat","Rocky Linux","AlmaLinux","SUSE",
         "openSUSE","Alpine","Photon OS","Mageia","Chainguard","Wolfi"]
      | index($e) != null;

    (.vulns // []) as $all
    | ($all | map(select(
        (.id | distro_id)
        or ( (((.affected // []) | length) > 0)
             and ((.affected // []) | all(.package.ecosystem // "" | distro_eco)) )
      ))) as $distro
    | ($all - $distro) as $up
    | ($distro
        | map( (((.affected // []) | map(.package.ecosystem // "" | split(":")[0])) | unique) as $e
               | if ($e | length) == 0 then ["id-prefix"] else $e end )
        | flatten | group_by(.) | map({e: .[0], n: length})) as $eco
    | ($up | map( ([.id] + (.aliases // [])) | unique )) as $sets
    | (reduce $sets[] as $s ([];
         ( [ .[] | select( . as $t | $s | any(. as $x | ($t | index($x)) != null) ) ] ) as $hit
         | ( [ .[] | select( ( . as $t | $s | any(. as $x | ($t | index($x)) != null) ) | not ) ] ) as $rest
         | $rest + [ (($hit | add // []) + $s) | unique ]
       )) as $groups
    | ($up | map({id: .id, rel: (.related // [])}) | map(select((.rel | length) > 0))) as $rels
    | [ "record-total\t\($all | length)"
      , "record-distro\t\($distro | length)"
      , "record-upstream\t\($up | length)"
      , "group-count\t\($groups | length)"
      ]
      + ($eco    | map("distro-ecosystem\t\(.e)|\(.n)"))
      + ($up     | map("upstream-id\t\(.id)"))
      + ($groups | map("group\t\(join(","))"))
      + ($rels   | map(. as $r | $r.rel | map("related-link\t\($r.id)|\(.)")) | flatten)
    | .[]
  '

  if ! jq -r "$prog" "$in" > "$out.part" 2>/dev/null; then
    echo "advisory_classify: could not classify the response." >&2
    rm -f "$out.part"
    return 2
  fi
  LC_ALL=C sort "$out.part" > "$out"
  rm -f "$out.part"
  return 0
}

advisory_fact() { awk -F'\t' -v k="$1" '$1==k {print $2}' "$2"; }

# Querying lives here rather than in a phase script so that Phase 1 and Phase 2
# cannot end up asking the same question two slightly different ways.
# Repointable at an internal mirror, which also lets the failure path be
# exercised without any external traffic.
ADVISORY_OSV_URL="${ECISF_OSV_URL:-https://api.osv.dev/v1/query}"

advisory_osv_query() { # payload outfile -> 0 ok, 2 inconclusive
  local payload="$1" out="$2" code rc
  command -v curl >/dev/null 2>&1 || { echo "        curl is missing; no query was made."; return 2; }
  code=$(curl -sS --max-time 25 -o "$out" -w '%{http_code}' \
         -H 'Content-Type: application/json' \
         --data-binary "$payload" "$ADVISORY_OSV_URL" 2>/dev/null)
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    echo "        query FAILED (curl exit $rc). This is not zero advisories."
    return 2
  fi
  if [[ "$code" != "200" ]]; then
    echo "        query returned HTTP $code. This is not zero advisories."
    return 2
  fi
  return 0
}

# Overridable so the reference can be repointed if the advisory it relies on
# ever changes upstream.
ADVISORY_CAL_ECO="${ECISF_OSV_CAL_ECO:-npm}"
ADVISORY_CAL_NAME="${ECISF_OSV_CAL_NAME:-lodash}"
ADVISORY_CAL_BAD="${ECISF_OSV_CAL_BAD:-4.17.15}"
ADVISORY_CAL_GOOD="${ECISF_OSV_CAL_GOOD:-4.17.21}"

# Proves the query path can SEE a known positive before any zero is believed,
# and that the version filter discriminates rather than answering the same way
# regardless of input. The negative control is deliberately RELATIVE: a fixed
# release still carries records, so "must return zero" would fail on a healthy
# database and pass on a broken one.
advisory_osv_calibrate() { # workdir -> 0 passed, 2 failed
  local w="$1" pos="" neg=""
  echo "  Calibration — can this query path see a KNOWN advisory?"
  if advisory_osv_query \
       "{\"package\":{\"name\":\"$ADVISORY_CAL_NAME\",\"ecosystem\":\"$ADVISORY_CAL_ECO\"},\"version\":\"$ADVISORY_CAL_BAD\"}" \
       "$w/cal-bad.json" \
     && advisory_classify "$w/cal-bad.json" "$w/cal-bad.facts" 2>/dev/null; then
    pos=$(advisory_fact record-total "$w/cal-bad.facts")
  fi
  if advisory_osv_query \
       "{\"package\":{\"name\":\"$ADVISORY_CAL_NAME\",\"ecosystem\":\"$ADVISORY_CAL_ECO\"},\"version\":\"$ADVISORY_CAL_GOOD\"}" \
       "$w/cal-good.json" \
     && advisory_classify "$w/cal-good.json" "$w/cal-good.facts" 2>/dev/null; then
    neg=$(advisory_fact record-total "$w/cal-good.facts")
  fi
  echo "      positive control $ADVISORY_CAL_NAME@$ADVISORY_CAL_BAD  -> ${pos:-<no answer>} record(s)"
  echo "      negative control $ADVISORY_CAL_NAME@$ADVISORY_CAL_GOOD -> ${neg:-<no answer>} record(s)"
  if [[ -n "$pos" && -n "$neg" && "$pos" -gt 0 && "$neg" -lt "$pos" ]]; then
    echo "  ✅  calibration PASSED: the path sees a known positive, and the"
    echo "      version filter distinguishes a fixed release from a vulnerable one."
    return 0
  fi
  echo "  🛑 calibration FAILED. No advisory result below can be believed,"
  echo "      because a broken query and a clean dependency both return zero."
  return 2
}

# Prints the standard evidence block. Shared so Phase 1 and Phase 2 cannot
# describe the same numbers with different wording.
advisory_summary() {
  local facts="$1" subject="${2:-the queried package}"
  local total distro upstream groups rel
  total=$(advisory_fact record-total "$facts")
  distro=$(advisory_fact record-distro "$facts")
  upstream=$(advisory_fact record-upstream "$facts")
  groups=$(advisory_fact group-count "$facts")
  rel=$(grep -c '^related-link' "$facts")

  echo "  records returned      : ${total:-0}"
  if [[ "${distro:-0}" -gt 0 ]]; then
    echo "  filtered as distro    : $distro"
    advisory_fact distro-ecosystem "$facts" | while IFS='|' read -r eco n; do
      echo "      $eco: $n"
    done
    echo "      Distro records describe a packaging ecosystem this artifact is"
    echo "      not part of. They are excluded, not resolved."
  fi
  echo "  upstream records      : ${upstream:-0}"
  echo "  distinct defects      : ${groups:-0}   (after alias de-duplication)"

  if [[ "$rel" -gt 0 ]]; then
    echo
    echo "  ⚠️  $rel 'related' cross-link(s) found. These are NOT merged automatically,"
    echo "      because 'related' does not always mean 'same defect'. Read them"
    echo "      before counting the linked IDs as separate problems — one defect"
    echo "      re-issued by a second CNA has already inflated a risk picture here:"
    grep '^related-link' "$facts" | sed 's/^related-link\t/      /; s/|/  ->  /'
  fi

  if [[ "${total:-0}" -eq 0 ]]; then
    echo
    echo "  ⚠️  ZERO records returned. This is NOT a clean result on its own."
    echo "      A broken query returns zero too. Treat it as a finding only if a"
    echo "      calibration query against a KNOWN-vulnerable version returned a"
    echo "      positive through this same code path."
  elif [[ "${upstream:-0}" -eq 0 ]]; then
    echo
    echo "  ⚠️  Every record was filtered out as the wrong ecosystem. That leaves"
    echo "      NO upstream evidence either way for $subject — it is an absence of"
    echo "      data, not an absence of vulnerabilities."
  fi
}
