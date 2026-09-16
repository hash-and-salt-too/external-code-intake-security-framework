#!/bin/bash
# Phase 5 canary check.
# Searches rendered output for the canary strings, in both plain and base64
# form. Reads only. Changes nothing.

set -u

DIR=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=kit-common.sh
. "$DIR/kit-common.sh" || exit 2
kit_parse_common "$@" || exit 2
if [ "$KIT_HELP" -eq 1 ]; then
    echo "Usage: 03-check-canary.sh [options]"; echo; kit_common_options; exit 0
fi
kit_validate_common || exit 2

OUT=$(kit_out)
PROBE="$HOME/probe"
RENDERED="$PROBE/rendered-canary.html"

echo "=============================================================="
echo " Canary check - did an unrelated file get embedded?"
echo "=============================================================="
echo

if [ ! -f "$RENDERED" ]; then
    echo "ERROR: no rendered output found at:"
    echo "  $RENDERED"
    echo
    echo "Produce it first with the artifact's own rendering path. If it has"
    echo "options that control raw HTML or inline images, turn them ON - without"
    echo "them you will not exercise the code path under test and would get a"
    echo "false all-clear. Write the result to:"
    echo
    echo "      $RENDERED"
    echo
    echo "  using probe file: $PROBE/03-traversal-canary.$KIT_EXT"
    exit 1
fi

if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "ERROR: canary file missing. Run 01-setup.sh first."
    exit 1
fi

# Defined in kit-common.sh. These MUST be the same strings 01-setup.sh planted:
# two separate copies could drift, and this script would then search for a
# string that was never written and report that as a clean result.
CANARY_SSH="$KIT_CANARY_SSH"
CANARY_AWS="$KIT_CANARY_AWS"
B64_SSH=$(base64 -i "$HOME/.ssh/id_rsa" | tr -d '\n')
B64_AWS=$(base64 -i "$HOME/.aws/credentials" | tr -d '\n')

FOUND=0

# -F means "treat the pattern as a literal string, not a regular expression".
# Base64 can contain + and / which would otherwise be interpreted as syntax.
check() {
    label="$1"
    needle="$2"
    if grep -qF -- "$needle" "$RENDERED" 2>/dev/null; then
        echo "  *** FOUND: $label"
        FOUND=1
    else
        echo "  not found: $label"
    fi
}

echo "Searching: $RENDERED"
echo "File size: $(wc -c < "$RENDERED" | tr -d ' ') bytes"
echo
check "fake SSH key, plain text"   "$CANARY_SSH"
check "fake SSH key, base64"       "$B64_SSH"
check "fake AWS creds, plain text" "$CANARY_AWS"
check "fake AWS creds, base64"     "$B64_AWS"
# Partial match, in case the output wraps the base64 across lines
check "fake SSH key, base64 (first 24 chars)" "$(printf '%s' "$B64_SSH" | cut -c1-24)"
echo

# Also look for the tell-tale shape of an embedded non-image file
echo "Embedded data: URIs with a non-standard image type:"
grep -o 'data:image/[a-zA-Z0-9._-]*;base64' "$RENDERED" 2>/dev/null \
    | sort -u | sed 's/^/    /' || true
echo "  (an empty type, like 'data:image/;base64', means a file with no"
echo "   extension was embedded - exactly what finding #22 predicted)"
echo

mkdir -p "$OUT" 2>/dev/null
{
    echo "Canary check run: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Rendered file: $RENDERED"
    echo "Size: $(wc -c < "$RENDERED" | tr -d ' ') bytes"
    echo
    echo "plain ssh   : $(grep -cF -- "$CANARY_SSH" "$RENDERED" 2>/dev/null) hits"
    echo "base64 ssh  : $(grep -cF -- "$B64_SSH" "$RENDERED" 2>/dev/null) hits"
    echo "plain aws   : $(grep -cF -- "$CANARY_AWS" "$RENDERED" 2>/dev/null) hits"
    echo "base64 aws  : $(grep -cF -- "$B64_AWS" "$RENDERED" 2>/dev/null) hits"
    echo
    echo "data: URI image types present:"
    grep -o 'data:image/[a-zA-Z0-9._-]*;base64' "$RENDERED" 2>/dev/null | sort -u
} > "$OUT/canary-check.txt" 2>&1
chmod a+r "$OUT/canary-check.txt" 2>/dev/null

echo "=============================================================="
if [ "$FOUND" -eq 1 ]; then
    echo " RESULT: FINDING #22 REPRODUCED"
    echo "=============================================================="
    echo
    echo " A file that has nothing to do with the previewed document was"
    echo " read from disk and embedded into the rendered output."
    echo
    echo " This is NOT yet proof of data theft. The content is sitting in"
    echo " the page - it has not necessarily gone anywhere. Whether it can"
    echo " LEAVE depends on whether JavaScript runs in the preview, which"
    echo " is what probe file 04-script-probe.md answers."
    echo
    echo " Check your listener log for /js-executed-img-onerror before"
    echo " drawing a conclusion."
else
    echo " RESULT: canary NOT found in the rendered output"
    echo "=============================================================="
    echo
    echo " On this path, the file was not embedded. Good."
    echo
    echo " Note the limitation: the command line tool does not share"
    echo " settings with the Quick Look extension, so this does not by"
    echo " itself clear the extension. Your log-window evidence from"
    echo " STEP 4 is what speaks to the extension's behaviour."
fi
echo
echo " Summary saved to: $OUT/canary-check.txt"
