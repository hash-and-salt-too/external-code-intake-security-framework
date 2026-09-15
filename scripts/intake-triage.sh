#!/usr/bin/env bash
# Intake triage: answers "do I even need this, and what will it cost?"
#
# This script NEVER decides whether something is safe. It gathers cheap,
# observable facts, forecasts what an audit would cost, and hands back to a
# human. It does not download, install, build, run, or inspect the artifact's
# contents — it reasons about the URL/path you give it plus this repo's own
# records.
#
# See docs/02-artifact-triage.md for the ladder this implements.
set -uo pipefail

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"; ASK="❓"

usage() {
  cat <<'EOF'
Usage:
  scripts/intake-triage.sh <url-or-path> [--job "what I need it to do"]

Implements gates G0-G2 from docs/02-artifact-triage.md:

  G0  Do I already have a trusted tool that does this job?
  G1  What type is it, and what will an audit cost?
  G2  Substitute / Work around / Stop+clear

It prints facts, a cost forecast, and paste-ready log lines. It does NOT
issue a security verdict, and it does not touch the artifact.

Options:
  --job "<text>"   What you actually need done. Used to search the capability
                   register. Strongly recommended — it is the whole point of G0.
  -h, --help       Show this message.

Examples:
  scripts/intake-triage.sh https://github.com/someone/thing/releases/tag/1.2.3 \
      --job "render markdown"
  scripts/intake-triage.sh https://www.example.com/downloads/Tool-2.0.dmg
EOF
}

TARGET=""; JOB=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --job) shift; JOB="${1:-}"; shift || true ;;
    -*) echo "$STOP Unrecognised option: $1"; echo; usage; exit 2 ;;
    *)  if [[ -z "$TARGET" ]]; then TARGET="$1"; shift; else
          echo "$STOP Unexpected extra argument: $1"; exit 2; fi ;;
  esac
done
[[ -z "$TARGET" ]] && { usage; exit 2; }

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPORTS="$REPO_ROOT/reports"
REGISTER="$REPORTS/capability-register.md"
[[ -f "$REGISTER" ]] || REGISTER="$REPORTS/capability-register.local.md"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
T=$(lower "$TARGET")
BASENAME="${TARGET##*/}"

# For a forge URL the meaningful name is the repo, not the trailing tag or
# filename — ".../QLMarkdown/releases/tag/1.5.0" should yield "QLMarkdown".
NAME="$BASENAME"
case "$T" in
  *github.com/*|*gitlab.com/*|*codeberg.org/*)
      NAME=$(printf '%s' "$TARGET" \
             | sed -E 's#^https?://[^/]+/##; s#^([^/]+)/([^/]+).*#\2#; s#\.git$##')
      ;;
esac
[[ -z "$NAME" ]] && NAME="$BASENAME"

echo "=================================================================="
echo " Intake triage — facts and cost forecast only, never a verdict"
echo " Target: $TARGET"
echo "=================================================================="

# ---------------------------------------------------------------- G0
echo
echo "--- G0: do I already have a trusted tool for this job? -------------"
if [[ -z "$JOB" ]]; then
  echo "$WARN No --job given, so this gate cannot be checked for you."
  echo "$INFO This is the cheapest question in the framework and it eliminates"
  echo "  more work than every other check combined. Re-run with:"
  echo "      --job \"what you actually need done\""
else
  echo "$INFO Job: \"$JOB\""
  if [[ -f "$REGISTER" ]]; then
    hits=""
    # Match on individual words so "render markdown" finds "Render / preview Markdown".
    for w in $JOB; do
      [[ ${#w} -lt 4 ]] && continue
      h=$(grep -i -- "$w" "$REGISTER" 2>/dev/null | grep '^|' | grep -v '^| Job' | grep -v '^|---')
      [[ -n "$h" ]] && hits="$hits$h"$'\n'
    done
    if [[ -n "$hits" ]]; then
      echo "$OK Possible existing capability found in the register:"
      printf '%s' "$hits" | sort -u | cut -c1-110 | sed 's/^/     /'
      echo
      echo "$ASK If one of these does the job, the disposition is SUBSTITUTE."
      echo "  Stop here. No artifact decision is needed — it never comes in."
    else
      echo "$INFO No match in the capability register for that job."
      echo "  Check it by eye anyway: $REGISTER"
    fi
  else
    echo "$WARN No capability register found at $REPORTS/capability-register.md"
  fi
fi

# ---------------------------------------------------------------- G1: type
echo
echo "--- G1: what is it? ------------------------------------------------"
TYPE=0; TYPE_NAME=""
case "$T" in
  *quicklook*|*qlgenerator*|*.appex*|*systemextension*|*spotlight*|*.kext*|*launchagent*|*launchdaemon*)
      TYPE=4; TYPE_NAME="System extension / OS add-on" ;;
  *marketplace.visualstudio.com*|*.vsix*|*open-vsx*)
      TYPE=7; TYPE_NAME="Editor / IDE extension" ;;
  *chrome.google.com/webstore*|*chromewebstore*|*addons.mozilla*|*safari-extensions*)
      TYPE=6; TYPE_NAME="Browser extension" ;;
  *npmjs.com*|*pypi.org*|*rubygems.org*|*crates.io*|*pkg.go.dev*|*cocoapods*|*packagist*)
      TYPE=5; TYPE_NAME="Package-manager library" ;;
  *docker*|*ghcr.io*|*quay.io*|*dockerfile*|*.tf|*terraform*|*ansible*)
      TYPE=8; TYPE_NAME="Container image / infrastructure code" ;;
  *.dmg|*.pkg|*.app|*.mpkg)
      TYPE=3; TYPE_NAME="Pre-built native app / binary" ;;
  *.sh|*.py|*.js|*.rb|*.ps1|*.bash|*.zsh|*.pl)
      TYPE=1; TYPE_NAME="Interpreted script" ;;
  *.git|*/releases/tag/*|*/archive/*|*.tar.gz|*.tgz|*.zip)
      TYPE=2; TYPE_NAME="Source you build yourself (or a release archive)" ;;
  *github.com/*|*gitlab.com/*|*codeberg.org/*)
      TYPE=2; TYPE_NAME="Source repository" ;;
esac

if [[ $TYPE -eq 0 ]]; then
  echo "$WARN Could not classify from the URL/path alone."
  echo "$INFO Identify the type by hand in docs/02-artifact-triage.md Step A,"
  echo "  and use the MOST POWERFUL type if several apply."
else
  echo "$INFO Type guess: ${TYPE} — ${TYPE_NAME}"
  echo "$WARN This is a guess from the name only. Confirm it against Step A."
  [[ $TYPE -eq 2 ]] && echo "$INFO If this repo ships a system extension or app, it is really type 3 or 4."
fi

# Install-time code execution is the thing that turns a cheap type into an expensive one.
echo
case "$TYPE" in
  1) echo "$WARN Runs with your FULL user privileges the moment it executes." ;;
  2) echo "$WARN The BUILD itself runs code (Makefiles, build.rs, postinstall, Xcode run-scripts)." ;;
  3) echo "$WARN Compiled — unreadable. A .pkg can run installer scripts as admin." ;;
  4) echo "$STOP Invoked AUTOMATICALLY by the OS, often on untrusted input. Highest routine risk." ;;
  5) echo "$WARN May run install-time scripts (npm postinstall, setup.py) before you ever use it." ;;
  6) echo "$WARN Can read pages, cookies and logged-in sessions per its permissions." ;;
  7) echo "$WARN Runs with your editor's privileges, often automatically on startup." ;;
  8) echo "$WARN The base image is not readable; infra code changes real systems." ;;
esac

# ---------------------------------------------------------------- G1: baseline
echo
echo "--- G1: is this already known? -------------------------------------"
STEM=$(printf '%s' "$NAME" | sed -E 's/[-_]?v?[0-9]+([._][0-9]+)*.*$//' | tr '[:upper:]' '[:lower:]')
# Vendors and this repo disagree about punctuation ("LittleSnitch-6.5.dmg" vs
# "little-snitch-v6.5.baseline.txt"), so compare on letters/digits only.
squash() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'; }
STEM_SQ=$(squash "$STEM")
BASELINE_HIT=""
if [[ -d "$REPORTS" && -n "$STEM_SQ" && ${#STEM_SQ} -ge 4 ]]; then
  for b in "$REPORTS"/*.baseline.txt; do
    [[ -e "$b" ]] || continue
    bsq=$(squash "$(basename "$b" .baseline.txt)")
    case "$bsq" in
      *"$STEM_SQ"*) BASELINE_HIT="$BASELINE_HIT$b"$'\n' ;;
    esac
  done
fi
if [[ -n "$BASELINE_HIT" ]]; then
  echo "$OK A baseline already exists — this is an UPDATE, not a first intake:"
  printf '%s\n' "$BASELINE_HIT" | sed "s|$REPO_ROOT/||" | sed 's/^/     /'
  echo "$INFO Go to docs/05-update-audit.md. Do NOT run a fresh intake."
  BAND="A"
else
  echo "$INFO No stored baseline matches \"$STEM\" — treat as first contact."
  case "$TYPE" in
    1|5) BAND="B" ;;
    2|3|6|7|8) BAND="C" ;;
    4) BAND="D" ;;
    *) BAND="?" ;;
  esac
fi

# ---------------------------------------------------------------- G1: forecast
echo
echo "--- G1: cost forecast ----------------------------------------------"
case "$BAND" in
  A) echo "$OK  BAND A — re-verify against a stored baseline."
     echo "     Expected: ~10–15 min. Fits the budget."
     echo "     Measured: 25 min first time; ~10–12 min on a clean repeat." ;;
  B) echo "$OK  BAND B — fast lane."
     echo "     Expected: ~10 min. Fits the budget."
     echo "$WARN Only stays band B if there are NO install-time scripts and"
     echo "     privilege is low. Check that before relying on this." ;;
  C) echo "$WARN BAND C — scheduled audit."
     echo "     Expected: 1–2 hours. Does NOT fit an interruption budget."
     echo "     Schedule it, or choose Substitute / Work around." ;;
  D) echo "$STOP BAND D — expensive."
     echo "     Expected: 4+ hours. Measured on a real type-4 artifact: 4h09m."
     echo "     Does NOT fit an interruption budget, and cannot be responsibly"
     echo "     shortened."
     echo
     echo "$STOP STANDING NOTE FOR BAND D:"
     echo "     If ANY substitute exists, take it. Rejecting costs you almost"
     echo "     nothing. Auditing costs you hours. A wrong accept costs you"
     echo "     unboundedly. The most expensive audit in this repo's history"
     echo "     ended in Reject, and a 30-second substitution check would have"
     echo "     reached the same place." ;;
  *) echo "$WARN BAND ? — unknown."
     echo "     The artifact type could not be determined from the name alone."
     echo "     Classify it by hand in docs/02-artifact-triage.md Step A before"
     echo "     choosing a disposition. Do not assume it is cheap." ;;
esac

# ---------------------------------------------------------------- G2
echo
echo "--- G2: your disposition (a human chooses this) --------------------"
cat <<'EOF'
  SUBSTITUTE   use a tool you already trust that does the same job
  WORK AROUND  finish the task without it
  STOP+CLEAR   park the task; run the intake as SCHEDULED work

  Substitute and Work around end here, with no artifact verdict —
  the artifact never comes in. That is the point.

  STOP+CLEAR does NOT mean "audit it in 15 minutes". It means the audit
  stops being an interruption and becomes its own scheduled task.
EOF

TODAY=$(date '+%Y-%m-%d')
cat <<EOF

--- paste-ready log lines (reports/intake-log.local.md) -------------
  $TODAY — Substitute: $NAME not assessed. Trusted tool already available: <TOOL>. Decided by me.
  $TODAY — Work around: $NAME not assessed. Task completed without it. Decided by me.
  $TODAY — Stop+clear: $NAME scheduled for band-$BAND audit. Decided by me.
EOF

cat <<EOF

--- if you are about to install it WITHOUT reviewing it -------------
$STOP That is not a deferral. It is an Accept with no evidence, and it
  inverts the rule that the gate is on execution. If you knowingly choose
  it, it does not go in the fast-lane list — it goes in the standing
  register at the top of reports/intake-log.local.md:

  | $TODAY | $NAME | <task that forced it> | <review-by date> | Accepted WITHOUT review |
EOF

# ---------------------------------------------------------------- hand-back
cat <<EOF

--- what this did NOT check ----------------------------------------
$INFO Nothing was downloaded, opened, executed or inspected. This tool
  reasoned only about the name you gave it and this repo's own records.
$INFO The type guess comes from the URL/path text alone and can be wrong.
  A repository URL says nothing about what the project actually ships.
$INFO No provenance, signature, dependency, source or behaviour check was
  performed. Those are the phases — this is only triage.
$INFO A cost band is a forecast, not a safety judgement. Band B does not
  mean "safe"; band D does not mean "malicious".

  A human owns the decision. This script never issues a verdict.
EOF
echo
echo "=================================================================="
exit 0
