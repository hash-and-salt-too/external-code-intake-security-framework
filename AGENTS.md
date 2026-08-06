# AGENTS.md — External Code Intake Security Framework

Orientation for any AI assistant working in this repo. Keep this file **lean and
durable** — it loads into every session, so bloat costs focus and money. Update
it when a *settled decision* changes.

**Last reviewed:** 2026-08-05

## What this project is

A beginner-friendly, **macOS-focused methodology for deciding whether externally
sourced code is safe to bring into a project and run — before it is executed,
installed, or incorporated.** It is documentation and checklists (no runtime
code yet). "External code" means anything originating outside the current
project (downloads, packages, AI-suggested dependencies, copied snippets),
judged by **provenance** — where it came from, not who or what wrote it. Any
scripts here are **read-only helpers** that gather evidence (e.g. checking
whether the local Xcode toolchain can even build a download) — they never
install, build, or run the code under review.

- Full rationale: [`docs/design-decisions.md`](docs/design-decisions.md)
- Start here: [`docs/README.md`](docs/README.md) → [`docs/00-scope-and-boundaries.md`](docs/00-scope-and-boundaries.md)
- To run an actual intake review, begin at [`docs/02-artifact-triage.md`](docs/02-artifact-triage.md) and pull in the relevant `docs/phases/` and `docs/checklists/`.

## Settled decisions (treat as given unless asked to revisit)

- **The gate is on execution, not download.** Fetching code to *read* it is fine;
  installing, building, or running it waits for a human decision.
- **Risk-proportional, two-speed:** a fast lane for low-risk items; a fuller
  audit for high-risk ones.
- **Four outcomes:** Accept · Accept-with-restrictions · Reject · Hold (needs a
  second look).
- **macOS-only for now** — structured so other platforms can be added later.
- **A human owns and records every decision.** The assistant gathers and explains
  evidence but must never turn uncertainty into a "yes."

## How to work here

- The maintainer favors plain, concrete explanations that are friendly to coders
  of varied experience levels: define jargon, keep steps reproducible, and be
  honest about what a quick check can and cannot prove.
- Value rigor **and** practicality — don't over-engineer, and don't let "auditing
  the audit" stall real work.
- Ask before large or structural changes.
- This is a **public** repo: keep organization-specific details out of it.

## Repo map

- `docs/` — the framework: scope, phases, checklists, templates, worked example.
- `scripts/` — small, **read-only** helpers (build-feasibility preflight;
  known-artifact drift check); never install, build, or run reviewed code.
- `tools/` — repo maintenance utilities that act only on **this repo's own
  files** (e.g. generating printable checklists); never touch reviewed code.
- `reports/` — one decision record per audited item (fast-lane items get a
  one-line entry). Index in `reports/README.md`.
- `provenance/` — private authorship records (git-ignored except its README).

## Maintaining this file

Keep it short and durable-only. When a settled decision or the working style
changes, update this file **in the same commit** and bump "Last reviewed." Every
so often (e.g., during a review/planning session), re-read it and flag anything
that has drifted from how the project actually works now.
