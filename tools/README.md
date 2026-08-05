# tools/ — repository maintenance utilities

Small helpers that operate on **this repository's own files**.

> **How this differs from [`../scripts/`](../scripts/):** `scripts/` holds
> **read-only helpers for the intake review itself** — they inspect *external
> code under review* and gather evidence (e.g. the build-feasibility preflight),
> and they never build or run that code. `tools/` never touches reviewed code at
> all; it maintains this repo's documentation. Keeping them apart preserves the
> safety promise attached to `scripts/`.

---

## `make-printable.sh` — Markdown → printable PDF + Word

**The problem it solves.** Some checklists are meant to be worked from **on
paper or in another user account** — notably the Phase 5 isolation setup, which
you follow *while logged in somewhere else*, and where you can't rely on having
this repo open. That needs a printable copy, but a printable copy silently goes
stale the moment the Markdown changes.

This script keeps the Markdown as the **single source of truth** and regenerates
every derived copy in one command, stamping each with its generation date.

### Usage

```bash
tools/make-printable.sh <markdown-file> [--share <dir>] [--width <n>]
```

```bash
# the Phase 5 checklist, plus a copy readable from the test account
tools/make-printable.sh docs/checklists/phase-5-isolation-setup.md \
    --share /Users/Shared
```

| Option | Effect |
|--------|--------|
| `--share <dir>` | Also refresh a copy of the **Markdown** in `<dir>` (mode `644`), so another account on this Mac can read it. |
| `--width <n>` | Wrap column for the printable text (default `76`). |

### What it produces

Beside the source: `<name>.pdf` (print-ready) and `<name>.docx` (Word/Pages, for
annotating instead of printing). Both open with a stamp:

```
DERIVED COPY -- generated 2026-08-04 19:46
Source of truth: docs/checklists/phase-5-isolation-setup.md
If the source has changed since the date above, REGENERATE before use.
```

That stamp is the whole point — **staleness is visible on page 1**, including on
a sheet of paper in a room away from this repo.

### Why the generated files aren't committed

`*.pdf`, `*.docx` and `*.rtf` are **git-ignored**. A committed printable is a
stale printable waiting to happen: someone prints it, works from it, and never
learns the source moved on. Regenerate on demand instead.

### Why no Markdown converter is installed

It uses only macOS built-ins — `sed`, `fold`, `cupsfilter`, `textutil` — so
nothing has to be added to the machine. Formatting is deliberately plain:
Markdown links collapse to their labels, heading/emphasis/code markers are
stripped, and `- [ ]` list items become `[  ]` boxes you can tick with a pen.

> **Tables don't survive** the flattening to plain text — they collapse into
> unreadable pipes. Prefer labelled bullet lists in any document you intend to
> print.

### The cleaner alternative to printing

If you only need the checklist readable from another account on the same Mac,
`--share /Users/Shared` is usually better than paper: nothing to reprint, and
fast user switching lets you keep working here. Paper still wins on one point —
it cannot be affected by whatever you're testing.
