---
mode: agent
description: "Guide me through a MANUAL external-code intake review, phase by phase, to a filed report — logging my effort with effortless start/pause/resume/end triggers. Pick a high-reasoning model (Opus)."
---

I'm doing a **manual** external-code intake review and I want you to guide me
through it end to end while measuring my effort. Target for this run:
**${input:target:What are you reviewing? (e.g. QLMarkdown)}**.

## First, get oriented
1. Read `AGENTS.md` and `docs/00-scope-and-boundaries.md`, then confirm in 2–3
   sentences that you've got the framework and my working style.
2. Run the triage in `docs/02-artifact-triage.md` for this target; tell me which
   phases apply and in what order. Pull in the relevant `docs/phases/` and
   `docs/checklists/` as we go.

## Effort logging — make this effortless for me
Keep a log at `reports/${input:target}-effort-log.local.md`. I give only four
plain triggers; **you** do all the timekeeping and arithmetic. On EVERY trigger,
read the real clock — run `date "+%Y-%m-%d %H:%M:%S"` in the terminal — never
estimate:
- **"start"** — begin the current phase (timestamp it).
- **"pause"** — I've stepped away (timestamp).
- **"resume"** — I'm back (timestamp).
- **"end"** — phase done (timestamp; compute **active time** = elapsed − paused
  spans; append a row to the log).

At each **end**, ask me two quick things in one line and record them:
(a) friction 1–5, and (b) was the phase **mostly mechanical** (deterministic → a
scripting candidate) **or judgment** (must stay human)?

If there's a long quiet gap and I forgot to "pause," check the clock and **ask**
before counting it as active time.

## Run the review
- One phase at a time, step by step, in plain language: for each step tell me
  what to do or run, the expected result, and what it means.
- Do the mechanical parts *with* me, but **I make every accept / accept-with-
  restrictions / reject / hold decision** — surface evidence, never decide for me.
- As each phase closes, write findings into the audit report
  `reports/${input:target}-intake.md` (from `docs/templates/audit-report-template.md`)
  so it doubles as our checkpoint — if we're interrupted, we resume from it.

## Finish
Once the report is filed and I've decided, give me a **brief raw retrospective**:
which steps were mechanical (scripting candidates) vs. judgment, where the
friction was, and what slowed me down — plainly enough that a later session can
turn it into scripts. Leave me two artifacts: the effort log and the report.
