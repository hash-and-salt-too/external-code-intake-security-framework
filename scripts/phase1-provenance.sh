#!/usr/bin/env bash
# Read-only Phase 1 provenance evidence collector.
#
# Gathers the deterministic half of docs/phases/phase-1-provenance.md: whether
# the repository is what it claims to be, whether it shows the texture of a real
# ongoing project, what its security posture looks like, and what commit a
# release tag actually resolves to.
#
# Phase 1 is entirely a set of remote questions, so unlike the other collectors
# it has no offline half at all. --online is therefore required rather than
# assumed: without it the script prints exactly what it WOULD ask and stops.
#
# gh is optional and is used ONLY to obtain a token, never as a second way of
# making the request. One request path cannot disagree with itself.
#
# It emits FACTS. The judgements this phase really turns on — is this maintainer
# credible, is a missing SECURITY.md acceptable here, was the arrival path
# trustworthy — are not computable and are left to a human, explicitly.
set -uo pipefail
export LC_ALL=C

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

usage() {
  cat <<'EOF'
Usage:
  scripts/phase1-provenance.sh <owner/repo> [options]

Options:
  --online             Required to gather anything. Contacts api.github.com and,
                       with --osv-package, api.osv.dev. Both are fixed endpoints
                       chosen by this script, not by the artifact.
  --tag <tag>          The release tag the review is pinned to. Resolved to the
                       immutable commit it actually points at, and its release
                       notes are scanned for signing / notarization claims.
  --osv-package <spec> Also query OSV for the software itself, as
                       <ecosystem>:<name>[:<version>] e.g. npm:lodash:4.17.15.
  -h, --help           Show this message.

Environment:
  ECISF_GH_API         Point GitHub queries at an enterprise instance.
  ECISF_OSV_URL        Point advisory queries at a mirror.

Exit codes (they describe findings, never approval):
  0  Evidence collected.
  1  The repository does not exist at that owner/repo. You cannot audit what is
     not there, and a typosquat is the reason to check.
  2  Inconclusive: no --online, bad arguments, rate limiting, or a calibration
     that failed. Nothing gathered under these conditions should be believed.
EOF
}

REPO=""; ONLINE=0; TAG=""; OSVSPEC=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --online) ONLINE=1; shift ;;
    --tag)         shift; TAG="${1:-}";     shift || true ;;
    --osv-package) shift; OSVSPEC="${1:-}"; shift || true ;;
    -*) echo "$STOP Unrecognised argument: $1"; echo; usage; exit 2 ;;
    *)
      if [[ -n "$REPO" ]]; then
        echo "$STOP More than one repository given: $REPO and $1"; exit 2
      fi
      REPO="$1"; shift ;;
  esac
done

[[ -z "$REPO" ]] && { usage; exit 2; }
case "$REPO" in
  */*/*|/*|*/) echo "$STOP Expected exactly owner/repo, got: $REPO"; exit 2 ;;
  */*) ;;
  *) echo "$STOP Expected owner/repo, got: $REPO"; exit 2 ;;
esac
OWNER="${REPO%%/*}"; NAME="${REPO##*/}"
[[ -z "$OWNER" || -z "$NAME" ]] && { echo "$STOP Expected owner/repo, got: $REPO"; exit 2; }

for t in curl jq awk sed grep; do
  command -v "$t" >/dev/null 2>&1 || { echo "$STOP Required tool missing: $t"; exit 2; }
done

GH_API="${ECISF_GH_API:-https://api.github.com}"

if [[ "$ONLINE" -eq 0 ]]; then
  cat <<EOF
$STOP Phase 1 asks only remote questions, so nothing was gathered.

Re-run with --online to ask GitHub, in one request path, for:
  GET $GH_API/repos/$OWNER/$NAME                 identity, fork status, licence
  GET $GH_API/users/$OWNER                       account age and type
  GET $GH_API/repos/$OWNER/$NAME/releases        release history
  GET $GH_API/repos/$OWNER/$NAME/contributors    bus factor
  GET $GH_API/repos/$OWNER/$NAME/contents/SECURITY.md
  GET $GH_API/repos/$OWNER/$NAME/contents/.github/workflows
  GET $GH_API/repos/$OWNER/$NAME/security-advisories

$INFO Nothing was contacted. Exit 2 means no evidence, not a clean result.
EOF
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -r "$SCRIPT_DIR/lib/advisory-query.sh" ]]; then
  echo "$STOP Missing shared classifier: $SCRIPT_DIR/lib/advisory-query.sh" >&2
  exit 2
fi
# shellcheck source=lib/advisory-query.sh
. "$SCRIPT_DIR/lib/advisory-query.sh"

WORK=$(mktemp -d) || { echo "$STOP Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT

BLOCKER=0; INCONCLUSIVE=0

# gh is used only to borrow a token. Branching into a second request mechanism
# would let the two paths return different answers for the same question.
GH_TOKEN_VAL=""; GH_AUTH="anonymous (60 requests/hour)"
if command -v gh >/dev/null 2>&1; then
  GH_TOKEN_VAL=$(gh auth token 2>/dev/null | tr -d '\r\n')
  [[ -n "$GH_TOKEN_VAL" ]] && GH_AUTH="token borrowed from gh"
fi

GH_CODE=""
gh_get() { # path outfile -> 0 ok, 1 not found, 2 inconclusive
  local p="$1" out="$2" rc
  : > "$out"
  if [[ -n "$GH_TOKEN_VAL" ]]; then
    GH_CODE=$(curl -sS --max-time 25 -o "$out" -D "$WORK/hdr.txt" -w '%{http_code}' \
      -H 'Accept: application/vnd.github+json' \
      -H "Authorization: Bearer $GH_TOKEN_VAL" "$GH_API$p" 2>/dev/null)
  else
    GH_CODE=$(curl -sS --max-time 25 -o "$out" -D "$WORK/hdr.txt" -w '%{http_code}' \
      -H 'Accept: application/vnd.github+json' "$GH_API$p" 2>/dev/null)
  fi
  rc=$?
  [[ "$rc" -ne 0 ]] && { GH_CODE="curl-$rc"; return 2; }
  case "$GH_CODE" in
    200) jq -e . "$out" >/dev/null 2>&1 || return 2; return 0 ;;
    404) return 1 ;;
    403|429) return 2 ;;
    *) return 2 ;;
  esac
}

echo "=================================================================="
echo " Phase 1 — provenance evidence (read-only)"
echo " Repository: $OWNER/$NAME"
echo " API: $GH_API   auth: $GH_AUTH"
echo " Collected: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="

# --- Calibration -----------------------------------------------------------
# Without this, a rate-limited or broken API makes an unknown repository and a
# non-existent one look identical, and "no releases, no contributors" reads as
# a finding about the project rather than about the connection.
echo
echo "--- Calibration -----------------------------------------------------"
CAL_OK=1
gh_get "/repos/octocat/Hello-World" "$WORK/cal-pos.json"
if [[ $? -ne 0 ]] || ! jq -e 'has("full_name")' "$WORK/cal-pos.json" >/dev/null 2>&1; then
  echo "  $STOP positive control FAILED (HTTP $GH_CODE) — a known repository"
  echo "      could not be read, so nothing below can be believed."
  CAL_OK=0
else
  echo "  $OK  positive control: a known repository reads back correctly"
fi
gh_get "/repos/octocat/ecisf-absent-$$-$(date +%s)" "$WORK/cal-neg.json"
if [[ $? -eq 1 ]]; then
  echo "  $OK  negative control: a missing repository returns 404, so absent"
  echo "      is distinguishable from broken"
else
  echo "  $STOP negative control FAILED (HTTP $GH_CODE) — a repository that"
  echo "      cannot exist did not return 404. 'Not found' is unreliable here."
  CAL_OK=0
fi
if [[ "$CAL_OK" -eq 0 ]]; then
  INCONCLUSIVE=1
  rl=$(sed -n 's/^[Xx]-[Rr]ate[Ll]imit-[Rr]emaining: *//p' "$WORK/hdr.txt" | tr -d '\r')
  [[ -n "$rl" ]] && echo "  $INFO rate limit remaining: $rl"
  echo
  echo "$STOP Calibration failed. Stopping rather than reporting findings that"
  echo "  cannot be distinguished from a broken connection."
  exit 2
fi

# --- Identity --------------------------------------------------------------
echo
echo "--- Identity --------------------------------------------------------"
gh_get "/repos/$OWNER/$NAME" "$WORK/repo.json"
case $? in
  1)
    echo "  $STOP $OWNER/$NAME does not exist."
    echo "      Check the spelling against the project's official site. A"
    echo "      near-miss name is what a typosquat relies on."
    exit 1 ;;
  2)
    echo "  $STOP could not read the repository (HTTP $GH_CODE)."
    exit 2 ;;
esac

R="$WORK/repo.json"
echo "  full name      : $(jq -r '.full_name // "?"' "$R")"
echo "  visibility     : $(jq -r 'if .private then "private" else "public" end' "$R")"
echo "  description    : $(jq -r '.description // "(none)"' "$R")"

# A missing field must never read as false. An API change or a wrong parse would
# otherwise quietly report every fork as an original.
if jq -e 'has("fork")' "$R" >/dev/null 2>&1; then
  if [[ "$(jq -r '.fork' "$R")" == "true" ]]; then
    echo "  $WARN fork          : YES — forked from $(jq -r '.parent.full_name // "unknown"' "$R")"
    echo "      A fork can be legitimate. Ask why you are installing the copy"
    echo "      rather than the source; poisoned forks differ by a few lines."
  else
    echo "  $OK  fork          : no, this is the original"
  fi
else
  echo "  $STOP fork          : field ABSENT from the response — undetermined."
  echo "      Not the same as 'not a fork'."
  INCONCLUSIVE=1
fi

arch=$(jq -r '.archived // false' "$R")
[[ "$arch" == "true" ]] && echo "  $WARN archived      : YES — read-only upstream, no security fixes will come"
echo "  default branch : $(jq -r '.default_branch // "?"' "$R")"
lic=$(jq -r '.license.spdx_id // ""' "$R")
if [[ -n "$lic" && "$lic" != "null" && "$lic" != "NOASSERTION" ]]; then
  echo "  $OK  licence       : $lic"
else
  echo "  $WARN licence       : none detected — unusual for a real project"
fi

# --- Pulse -----------------------------------------------------------------
echo
echo "--- Pulse -----------------------------------------------------------"
echo "  created        : $(jq -r '.created_at // "?"' "$R")"
echo "  last push      : $(jq -r '.pushed_at // "?"' "$R")"
echo "  stars / forks  : $(jq -r '.stargazers_count // 0' "$R") / $(jq -r '.forks_count // 0' "$R")"
echo "  open issues+PRs: $(jq -r '.open_issues_count // 0' "$R")"
if [[ "$(jq -r '.has_issues // false' "$R")" == "true" ]]; then
  echo "  $OK  issues        : enabled — public scrutiny is not suppressed"
else
  echo "  $WARN issues        : DISABLED on a project asking you to run code"
fi

count_paged() { # path label -> prints count, "100+" when the page is full
  local p="$1" f="$WORK/paged.json" n
  gh_get "$p" "$f" || { echo "undetermined"; return; }
  n=$(jq -r 'if type=="array" then length else 0 end' "$f")
  if [[ "$n" -ge 100 ]]; then echo "100+"; else echo "$n"; fi
}
echo "  releases       : $(count_paged "/repos/$OWNER/$NAME/releases?per_page=100")"
echo "  contributors   : $(count_paged "/repos/$OWNER/$NAME/contributors?per_page=100")"
echo "  $INFO One contributor is normal for a small tool and is also a single"
echo "    point of compromise. Stars corroborate; they never audit."

# --- Owner -----------------------------------------------------------------
echo
echo "--- Owner -----------------------------------------------------------"
if gh_get "/users/$OWNER" "$WORK/owner.json"; then
  echo "  account        : $OWNER ($(jq -r '.type // "?"' "$WORK/owner.json"))"
  echo "  created        : $(jq -r '.created_at // "?"' "$WORK/owner.json")"
  echo "  public repos   : $(jq -r '.public_repos // 0' "$WORK/owner.json")"
  echo "  $INFO A years-old account with a body of real work is more credible"
  echo "    than one that exists only to host this download. Whether THIS"
  echo "    maintainer is credible is a judgement, and it stays with you."
else
  echo "  $WARN could not read the owner account (HTTP $GH_CODE)"
  INCONCLUSIVE=1
fi

# --- Security posture ------------------------------------------------------
echo
echo "--- Security posture ------------------------------------------------"
gh_get "/repos/$OWNER/$NAME/contents/SECURITY.md" "$WORK/sec.json"
case $? in
  0) echo "  $OK  SECURITY.md   : present" ;;
  1) echo "  $WARN SECURITY.md   : absent — no documented way to report a flaw" ;;
  *) echo "  $WARN SECURITY.md   : undetermined (HTTP $GH_CODE)"; INCONCLUSIVE=1 ;;
esac
gh_get "/repos/$OWNER/$NAME/contents/.github/workflows" "$WORK/wf.json"
case $? in
  0) echo "  $INFO CI workflows   : $(jq -r 'if type=="array" then length else 0 end' "$WORK/wf.json") file(s)" ;;
  1) echo "  $WARN CI workflows   : none — releases are built on someone's own"
     echo "      machine, with no reproducible or attested pipeline" ;;
  *) echo "  $WARN CI workflows   : undetermined (HTTP $GH_CODE)"; INCONCLUSIVE=1 ;;
esac
gh_get "/repos/$OWNER/$NAME/security-advisories" "$WORK/adv.json"
case $? in
  0) n=$(jq -r 'if type=="array" then length else 0 end' "$WORK/adv.json")
     echo "  $INFO published advisories: $n"
     [[ "$n" -gt 0 ]] && echo "      Past advisories are a maturity signal, not a fault." ;;
  1) echo "  $INFO published advisories: none listed" ;;
  *) echo "  $WARN published advisories: undetermined (HTTP $GH_CODE)"; INCONCLUSIVE=1 ;;
esac

# --- Pinned version --------------------------------------------------------
echo
echo "--- Pinned version --------------------------------------------------"
if [[ -z "$TAG" ]]; then
  echo "  $WARN No --tag given, so nothing was pinned."
  echo "      Everything after this phase must target one unchanging version,"
  echo "      or you audit one thing and run another."
else
  if gh_get "/repos/$OWNER/$NAME/git/ref/tags/$TAG" "$WORK/ref.json"; then
    objtype=$(jq -r '.object.type // "?"' "$WORK/ref.json")
    objsha=$(jq -r '.object.sha // ""' "$WORK/ref.json")
    # An ANNOTATED tag points at a tag object, not at a commit. Reporting that
    # sha as "the commit" would be confidently wrong, and it is the sha a
    # reviewer would then paste into a clone command.
    if [[ "$objtype" == "tag" ]]; then
      if gh_get "/repos/$OWNER/$NAME/git/tags/$objsha" "$WORK/tagobj.json"; then
        commit=$(jq -r '.object.sha // ""' "$WORK/tagobj.json")
        echo "  tag $TAG is ANNOTATED"
        echo "    tag object   : $objsha"
        echo "    $OK  commit   : $commit"
      else
        echo "  $WARN annotated tag could not be dereferenced (HTTP $GH_CODE)"
        INCONCLUSIVE=1
      fi
    else
      echo "  tag $TAG is lightweight"
      echo "    $OK  commit   : $objsha"
    fi
  else
    echo "  $WARN tag '$TAG' not found (HTTP $GH_CODE)"
    INCONCLUSIVE=1
  fi

  if gh_get "/repos/$OWNER/$NAME/releases/tags/$TAG" "$WORK/rel.json"; then
    echo "  release        : $(jq -r '.name // .tag_name // "?"' "$WORK/rel.json")  published $(jq -r '.published_at // "?"' "$WORK/rel.json")"
    [[ "$(jq -r '.prerelease // false' "$WORK/rel.json")" == "true" ]] && echo "  $WARN marked as a PRERELEASE"
    body=$(jq -r '.body // ""' "$WORK/rel.json")
    if printf '%s' "$body" | grep -Eiq 'notariz|codesign|code.sign|signed|signature|sha256|checksum'; then
      echo "  $INFO release notes mention signing / notarization / checksums:"
      printf '%s\n' "$body" | grep -Ei 'notariz|codesign|code.sign|signed|signature|sha256|checksum' | sed 's/^/        /'
      echo "      A claim in release notes is not verification. Phase 4 checks it."
    else
      echo "  $INFO release notes make no signing or checksum claim"
    fi
  else
    echo "  $INFO no published release for tag '$TAG' (HTTP $GH_CODE)"
  fi
fi

# --- Advisories for the software itself ------------------------------------
if [[ -n "$OSVSPEC" ]]; then
  echo
  echo "--- Advisories for the software itself -------------------------------"
  osv_eco="${OSVSPEC%%:*}"; rest="${OSVSPEC#*:}"
  osv_name="${rest%%:*}"; osv_ver=""
  [[ "$rest" == *:* ]] && osv_ver="${rest##*:}"
  if [[ -z "$osv_eco" || -z "$osv_name" || "$osv_eco" == "$OSVSPEC" ]]; then
    echo "  $STOP --osv-package expects <ecosystem>:<name>[:<version>]"
    INCONCLUSIVE=1
  elif ! advisory_require_tools; then
    INCONCLUSIVE=1
  elif ! advisory_osv_calibrate "$WORK"; then
    INCONCLUSIVE=1
  else
    if [[ -n "$osv_ver" ]]; then
      payload="{\"package\":{\"name\":\"$osv_name\",\"ecosystem\":\"$osv_eco\"},\"version\":\"$osv_ver\"}"
    else
      payload="{\"package\":{\"name\":\"$osv_name\",\"ecosystem\":\"$osv_eco\"}}"
    fi
    echo
    echo "  $osv_eco:$osv_name${osv_ver:+@$osv_ver}"
    if advisory_osv_query "$payload" "$WORK/osv.json" \
       && advisory_classify "$WORK/osv.json" "$WORK/osv.facts" 2>/dev/null; then
      advisory_summary "$WORK/osv.facts" "$osv_name"
    else
      echo "      $STOP query inconclusive — not a clean result."
      INCONCLUSIVE=1
    fi
  fi
fi

# --- Close -----------------------------------------------------------------
rl=$(sed -n 's/^[Xx]-[Rr]ate[Ll]imit-[Rr]emaining: *//p' "$WORK/hdr.txt" | tr -d '\r')
echo
echo "=================================================================="
[[ -n "$rl" ]] && echo " API requests remaining this hour: $rl"
cat <<'EOF'
 These are facts, not a verdict. The questions this phase really turns
 on are NOT answered above, because they are not computable:

   how you arrived here, and whether that path was trustworthy
   whether this maintainer reads as a careful engineer
   whether a missing SECURITY.md is acceptable for THIS project
   whether to pin the newest release or a longer-exposed older one

 A script would answer the last one "newest" and be wrong for the
 reasons this framework exists. Record your own answers.
==================================================================
EOF

if [[ "$BLOCKER" -ne 0 ]]; then exit 1; fi
if [[ "$INCONCLUSIVE" -ne 0 ]]; then exit 2; fi
exit 0
