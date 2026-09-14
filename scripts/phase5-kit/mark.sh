#!/bin/bash
# Phase 5 timing mark - QLMarkdown v1.5.0 intake review
#
# Records a real clock reading against a label, so the reviewer never has to
# do arithmetic and never has to switch accounts mid-task just to report a
# time. Reads the system clock; never estimates.
#
#   bash /Users/Shared/phase5-kit/mark.sh prep-start

set -u

KIT="/Users/Shared/phase5-kit"
OUT="$KIT/out"
LOG="$OUT/timestamps.txt"

usage() {
    echo "Usage:  bash $KIT/mark.sh <label>"
    echo
    echo "Labels:"
    echo "   prep-start    before you open the three Terminal windows"
    echo "   prep-end      when 01-setup.sh prints READY"
    echo "   exec-start    at STEP 3a, copying the app in"
    echo "   exec-end      after STEP 7, listener log saved"
    echo "   pause         any time you step away"
    echo "   resume        when you come back"
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
LABEL="$1"

case "$LABEL" in
    prep-start|prep-end|exec-start|exec-end|pause|resume) ;;
    *)
        echo "Unknown label: $LABEL"
        echo
        usage
        exit 1
        ;;
esac

mkdir -p "$OUT" 2>/dev/null
if ! touch "$LOG" 2>/dev/null; then
    echo "ERROR: cannot write to $LOG"
    echo
    echo "Write down this time by hand instead, and report it later:"
    date "+%Y-%m-%d %H:%M:%S"
    exit 1
fi

NOW=$(date "+%Y-%m-%d %H:%M:%S")
printf '%s  %s\n' "$NOW" "$LABEL" >> "$LOG"
chmod a+r "$LOG" 2>/dev/null

echo "  marked : $LABEL"
echo "  time   : $NOW"

# Immediate feedback, so you can sanity-check as you go.
elapsed_since() {
    prev=$(awk -v l="$1" '$3 == l { print $1" "$2 }' "$LOG" | tail -1)
    [ -n "$prev" ] || return 0
    a=$(date -j -f "%Y-%m-%d %H:%M:%S" "$prev" "+%s" 2>/dev/null) || return 0
    b=$(date -j -f "%Y-%m-%d %H:%M:%S" "$NOW" "+%s" 2>/dev/null) || return 0
    d=$((b - a))
    printf '  elapsed since %s: %d:%02d:%02d\n' \
        "$1" $((d / 3600)) $(((d % 3600) / 60)) $((d % 60))
}

case "$LABEL" in
    prep-end) elapsed_since prep-start ;;
    exec-end) elapsed_since exec-start ;;
    resume)   elapsed_since pause ;;
esac

echo
echo "  recorded in: $LOG"
