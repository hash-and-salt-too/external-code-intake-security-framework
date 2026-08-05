#!/usr/bin/env bash
#
# make-printable.sh — turn a Markdown doc into printable PDF + Word files.
#
# Uses only macOS built-ins (sed, fold, cupsfilter, textutil): nothing to
# install. The Markdown stays the single source of truth; every generated file
# carries a dated "DERIVED COPY" stamp so a stale printout is visible on page 1.
#
# Generated files are git-ignored by design — see .gitignore.

set -euo pipefail

WIDTH=76
SHARE_DIR=""

usage() {
    cat <<'EOF'
Usage: tools/make-printable.sh <markdown-file> [options]

Options:
  --share <dir>   Also copy the Markdown source into <dir> (e.g. /Users/Shared),
                  so another user account on this Mac can read it. The copy is
                  refreshed on every run, which is the point: it goes stale
                  exactly as easily as the PDF does.
  --width <n>     Wrap column for the printable text (default: 76).
  -h, --help      Show this help.

Outputs, written beside the source:
  <name>.pdf      Print-ready.
  <name>.docx     Word/Pages, for annotating instead of printing.

Example:
  tools/make-printable.sh docs/checklists/phase-5-isolation-setup.md \
      --share /Users/Shared
EOF
}

[[ $# -ge 1 ]] || { usage; exit 2; }

SRC=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --share)   SHARE_DIR="${2:-}"; [[ -n "$SHARE_DIR" ]] || { echo "error: --share needs a directory" >&2; exit 2; }; shift 2 ;;
        --width)   WIDTH="${2:-}";     [[ "$WIDTH" =~ ^[0-9]+$ ]] || { echo "error: --width needs a number" >&2; exit 2; }; shift 2 ;;
        -*)        echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
        *)         [[ -z "$SRC" ]] || { echo "error: only one input file" >&2; exit 2; }; SRC="$1"; shift ;;
    esac
done

[[ -n "$SRC" ]]  || { echo "error: no Markdown file given" >&2; usage >&2; exit 2; }
[[ -f "$SRC" ]]  || { echo "error: not a file: $SRC" >&2; exit 1; }

for tool in cupsfilter textutil; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: '$tool' not found (expected on macOS)" >&2; exit 1; }
done

DIR="$(cd "$(dirname "$SRC")" && pwd)"
BASE="$(basename "${SRC%.*}")"
TITLE="$(sed -n '/^# /{s/^# //p;q;}' "$SRC")"
[[ -n "$TITLE" ]] || TITLE="$BASE"

STAMP="$(date '+%Y-%m-%d %H:%M')"
TMP="$(mktemp -t make-printable)"
trap 'rm -f "$TMP"' EXIT

RULE='________________________________________________________________________'

# Flatten Markdown to plain text: links to their labels, headings/emphasis/code
# markers removed, list bullets turned into tickable boxes.
{
    printf 'DERIVED COPY -- generated %s\n' "$STAMP"
    printf 'Source of truth: %s\n' "$SRC"
    printf 'If the source has changed since the date above, REGENERATE before use.\n'
    printf '%s\n\n' "$RULE"
    sed -E \
        -e 's/\[([^]]+)\]\([^)]+\)/\1/g' \
        -e 's/^#{1,6}[[:space:]]+//' \
        -e 's/\*\*//g' \
        -e 's/\*([^*]+)\*/\1/g' \
        -e 's/`//g' \
        -e 's/^> ?//' \
        -e "s/^---+$/$RULE/" \
        -e 's/^- \[ \] /[  ]  /' \
        -e 's/^- /  - /' \
        "$SRC"
} | fold -s -w "$WIDTH" > "$TMP"

cupsfilter -t "$TITLE" "$TMP" > "$DIR/$BASE.pdf" 2>/dev/null
textutil -convert docx -font Menlo -fontsize 10 -output "$DIR/$BASE.docx" "$TMP"

echo "generated $STAMP"
echo "  $DIR/$BASE.pdf"
echo "  $DIR/$BASE.docx"

if [[ -n "$SHARE_DIR" ]]; then
    [[ -d "$SHARE_DIR" ]] || { echo "error: --share dir does not exist: $SHARE_DIR" >&2; exit 1; }
    cp "$SRC" "$SHARE_DIR/"
    chmod 644 "$SHARE_DIR/$(basename "$SRC")"
    echo "  $SHARE_DIR/$(basename "$SRC")  (readable by other accounts)"
fi
