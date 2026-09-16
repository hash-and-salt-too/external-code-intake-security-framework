#!/usr/bin/env bash
# Read-only defaults-vs-documentation comparison for Phase 3.
#
# The problem it solves, from this framework's worked example (finding 23):
# the project's README said "by default, HTML tags are stripped and unsafe links
# are replaced by empty strings", while the source shipped the opposite —
# unsafeHTMLOption = true. The README accurately described the upstream
# LIBRARY's default; the application overrode it. A divergence between what the
# documentation promises and what the code sets, on a security-relevant default,
# is a finding in its own right, and it is invisible unless you put the two
# side by side.
#
# It EXTRACTS AND PAIRS. It never decides whether a claim and a default agree,
# because that needs reading comprehension: "stripped" contradicting
# "unsafeHTML = true" is obvious to a person and guesswork for a regex. A
# heuristic verdict here would be exactly the kind of confident wrong answer
# this repo refuses to produce.
#
# It reads files. It does not build, install, run or fetch anything.
set -uo pipefail
export LC_ALL=C

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

usage() {
  cat <<'EOF'
Usage:
  scripts/phase3-defaults-vs-docs.sh <source-tree> [options]

Puts every security-relevant default declared in the source next to every
"by default" claim made in the documentation, so a human can compare them.

Options:
  --docs <path>      A documentation file or directory to read. Repeatable.
                     Defaults to README* / *.md at the top of the source tree.
  --keyword <word>   Add a term to the security-relevant word list. Repeatable.
  --list-keywords    Print the built-in word list and exit.
  -h, --help         Show this message.

Exit codes (they describe findings, never approval):
  0  Evidence collected and paired.
  2  Inconclusive: bad arguments, no source read, no settings extracted from a
     tree that plainly contains some, or an extractor that failed its self-test.

It deliberately never exits 1. Whether a claim and a default actually disagree
is a reading judgement, and this script does not make it.
EOF
}

# Terms that make a boolean setting worth a human's attention. Deliberately
# broad: a false positive costs a glance, a false negative hides a finding 23.
KEYWORDS="unsafe raw html script javascript sanitiz sanitis validate verify
strict secure trust allow enable disable permit remote network external fetch
download exec shell privilege sandbox entitle telemetry analytics track update
auto insecure bypass skip ignore relax debug"

SRC=""; DOCPATHS=""; EXTRA=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --list-keywords) printf '%s\n' $KEYWORDS; exit 0 ;;
    --docs)    shift; DOCPATHS="$DOCPATHS ${1:-}"; shift || true ;;
    --keyword) shift; EXTRA="$EXTRA ${1:-}";       shift || true ;;
    -*) echo "$STOP Unrecognised argument: $1"; echo; usage; exit 2 ;;
    *)
      if [[ -n "$SRC" ]]; then
        echo "$STOP More than one source tree given: $SRC and $1"; exit 2
      fi
      SRC="$1"; shift ;;
  esac
done

[[ -z "$SRC" ]] && { usage; exit 2; }
[[ -d "$SRC" ]] || { echo "$STOP Source tree not found: $SRC"; exit 2; }
SRC="${SRC%/}"
KEYWORDS="$KEYWORDS $EXTRA"

WORK=$(mktemp -d) || { echo "$STOP Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT
INCONCLUSIVE=0

# One alternation built from the word list. tr needs a REAL newline here: in a
# single-quoted shell string '\n' is a literal backslash and an n, which would
# silently mangle every keyword containing the letter n.
KWRE=$(printf '%s' "$KEYWORDS" | tr -s '[:space:]' '|' | sed 's/^|//; s/|$//')
# Matching is two steps rather than one clause: find a line that assigns a
# boolean literal, then keep it only if the line mentions a security-relevant
# term. A single regex trying to do both has to span ": Bool =" and gets fragile.
VALRE="[:=][[:space:]]*(true|false|YES|NO)[[:space:],;)]*$"

# A pattern that matches nothing yields an empty report, and an empty report
# reads as "no divergence". Prove the extractor sees a known positive first.
echo "=================================================================="
echo " Phase 3 — declared defaults vs documented defaults (read-only)"
echo " Source: $SRC"
echo " Collected: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="
echo
echo "--- Extractor self-test ---------------------------------------------"
SELFTEST='    var unsafeHTMLOption: Bool = true'
SELFNEG='    var showLineNumbers: Bool = true'
if printf '%s\n' "$SELFTEST" | grep -Eq "$VALRE" \
   && printf '%s\n' "$SELFTEST" | grep -Eqi -- "$KWRE"; then
  echo "  $OK  settings extractor sees a known-positive declaration"
else
  echo "  $STOP settings extractor FAILED its self-test. No result is reported,"
  echo "      because a broken extractor reports an empty, clean-looking list."
  exit 2
fi
# A filter that matches everything is as useless as one that matches nothing:
# it would bury a real finding in noise about window sizes.
if printf '%s\n' "$SELFNEG" | grep -Eqi -- "$KWRE"; then
  echo "  $STOP keyword filter FAILED its negative self-test: it matched a"
  echo "      setting with no security relevance. Every project would look"
  echo "      alarming and the real finding would be lost in the noise."
  exit 2
else
  echo "  $OK  keyword filter rejects a non-security declaration"
fi
CLAIMRE='by default|default(s)? to|default is|defaults are|enabled by default|disabled by default|on by default|off by default'
if printf 'By default, HTML tags are stripped.\n' | grep -Eiq "$CLAIMRE"; then
  echo "  $OK  documentation extractor sees a known-positive claim"
else
  echo "  $STOP documentation extractor FAILED its self-test."
  exit 2
fi

# --- Defaults declared in source -------------------------------------------
echo
echo "--- Security-relevant defaults declared in source -------------------"
find "$SRC" -type f \( -name '*.swift' -o -name '*.m' -o -name '*.mm' \
     -o -name '*.h' -o -name '*.c' -o -name '*.cpp' -o -name '*.js' \
     -o -name '*.ts' -o -name '*.py' -o -name '*.rb' -o -name '*.go' \
     -o -name '*.rs' -o -name '*.java' -o -name '*.kt' \) \
     -not -path '*/.git/*' 2>/dev/null | LC_ALL=C sort > "$WORK/srcfiles.txt"
src_n=$(grep -c . "$WORK/srcfiles.txt" | tr -d ' ')

: > "$WORK/settings.txt"
while read -r f; do
  [[ -n "$f" ]] || continue
  grep -EIn "$VALRE" "$f" 2>/dev/null \
    | grep -Ei -- "$KWRE" \
    | sed "s|^|${f#"$SRC"/}:|" >> "$WORK/settings.txt"
done < "$WORK/srcfiles.txt"
set_n=$(grep -c . "$WORK/settings.txt" | tr -d ' ')

echo "  source files scanned : $src_n"
echo "  boolean defaults hit : $set_n"
if [[ "$src_n" -eq 0 ]]; then
  echo "  $STOP No source files of a recognised language were found."
  echo "      That is an absence of input, not an absence of findings."
  INCONCLUSIVE=1
elif [[ "$set_n" -eq 0 ]]; then
  echo "  $WARN No security-relevant boolean default matched in $src_n file(s)."
  echo "      Either this project has none, or the word list does not cover its"
  echo "      vocabulary. Check with --list-keywords and extend with --keyword."
else
  echo
  sed 's/^/    /' "$WORK/settings.txt"
fi

# --- Claims made in documentation ------------------------------------------
echo
echo "--- Default claims made in documentation ----------------------------"
: > "$WORK/docfiles.txt"
if [[ -z "$DOCPATHS" ]]; then
  find "$SRC" -maxdepth 2 -type f \( -iname 'README*' -o -iname '*.md' \
       -o -iname '*.rst' -o -iname '*.txt' \) -not -path '*/.git/*' 2>/dev/null \
    | LC_ALL=C sort > "$WORK/docfiles.txt"
else
  for d in $DOCPATHS; do
    if [[ -d "$d" ]]; then
      find "$d" -type f \( -iname '*.md' -o -iname '*.rst' -o -iname '*.txt' \
           -o -iname 'README*' \) 2>/dev/null >> "$WORK/docfiles.txt"
    elif [[ -f "$d" ]]; then
      printf '%s\n' "$d" >> "$WORK/docfiles.txt"
    else
      echo "  $WARN --docs path not found, skipped: $d"
    fi
  done
  LC_ALL=C sort -u "$WORK/docfiles.txt" -o "$WORK/docfiles.txt"
fi
doc_n=$(grep -c . "$WORK/docfiles.txt" | tr -d ' ')

: > "$WORK/claims.txt"
while read -r f; do
  [[ -n "$f" ]] || continue
  grep -EIin "$CLAIMRE" "$f" 2>/dev/null | sed "s|^|${f#"$SRC"/}:|" >> "$WORK/claims.txt"
done < "$WORK/docfiles.txt"
claim_n=$(grep -c . "$WORK/claims.txt" | tr -d ' ')

echo "  documentation files  : $doc_n"
echo "  default claims found : $claim_n"
if [[ "$doc_n" -eq 0 ]]; then
  echo "  $WARN No documentation was read, so nothing can be compared against."
  echo "      Point at it with --docs. An unread README is not a silent pass."
  INCONCLUSIVE=1
elif [[ "$claim_n" -eq 0 ]]; then
  echo "  $INFO The documentation makes no explicit statement about defaults."
  echo "      That is itself worth recording: the defaults are undocumented."
else
  echo
  sed 's/^/    /' "$WORK/claims.txt"
fi

# --- Candidate pairings ----------------------------------------------------
echo
echo "--- Candidate pairings ----------------------------------------------"
if [[ "$set_n" -eq 0 || "$claim_n" -eq 0 ]]; then
  echo "  $INFO Nothing to pair: one side of the comparison is empty."
else
  paired=0
  : > "$WORK/pairedset.txt"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    # Strip the file:line prefix first: a path such as src/network/x.swift
    # would otherwise donate its own keyword and name the wrong setting.
    body=$(printf '%s' "$line" | sed 's|^[^:]*:[0-9]*:||')
    name=$(printf '%s' "$body" | grep -Eoi "[[:alnum:]_.]*(${KWRE})[[:alnum:]_.]*" | head -1)
    [[ -n "$name" ]] || continue
    words=$(printf '%s' "$name" \
            | sed 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g; s/[._]/ /g' \
            | tr 'A-Z' 'a-z' | tr -s ' ' '\n' \
            | awk 'length($0)>=4 && $0!="option" && $0!="options" && $0!="value" \
                   && $0!="setting" && $0!="settings" && $0!="default" && $0!="defaults"')
    [[ -n "$words" ]] || continue
    hits=""
    while IFS= read -r w; do
      [[ -n "$w" ]] || continue
      # No -n: claims.txt lines already carry their own file:line prefix, and a
      # second number in front of it just reads as noise.
      h=$(grep -Ei -- "$w" "$WORK/claims.txt" 2>/dev/null)
      [[ -n "$h" ]] && hits="$hits$h"$'\n'
    done <<EOF
$words
EOF
    if [[ -n "$hits" ]]; then
      paired=$((paired + 1))
      printf '%s\n' "$line" >> "$WORK/pairedset.txt"
      echo "  $WARN $line"
      printf '%s' "$hits" | LC_ALL=C sort -u | sed 's/^/        doc: /'
      echo
    fi
  done < "$WORK/settings.txt"

  if [[ "$paired" -eq 0 ]]; then
    echo "  $INFO No setting name shared a word with any documented claim."
  else
    echo "  $STOP READ THESE. This script has NOT decided whether any pair agrees."
    echo "      Judging whether \"stripped by default\" contradicts"
    echo "      \"unsafeHTML = true\" is reading comprehension, not pattern"
    echo "      matching, and a guess here would be a confident wrong answer."
  fi

  # Both directions matter: an undocumented default and a claim about something
  # that is not in the code are different findings, and each is easy to miss.
  echo
  echo "  Defaults with NO matching documentation claim:"
  n=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    grep -qxF -- "$line" "$WORK/pairedset.txt" 2>/dev/null && continue
    echo "      $line"; n=$((n + 1))
  done < "$WORK/settings.txt"
  [[ "$n" -eq 0 ]] && echo "      (none)"
  echo "      $INFO An undocumented security-relevant default is a finding."
fi

# --- Close -----------------------------------------------------------------
echo
echo "=================================================================="
echo " These are facts, not a verdict. The comparison itself is left to"
echo " you on purpose: the worked example's divergence was a README that"
echo " correctly described the upstream LIBRARY's default while the"
echo " application shipped the opposite. Only a reader can see that."
echo "=================================================================="

[[ "$INCONCLUSIVE" -ne 0 ]] && exit 2
exit 0
