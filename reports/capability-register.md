# Capability Register — "do I already have something that does this job?"

The lookup table for **G0**, the first question in
[`../docs/02-artifact-triage.md`](../docs/02-artifact-triage.md). Its only job is to
turn a memory test into a 30-second lookup.

> **Why this file exists.** A Quick Look Markdown previewer was audited over five phases
> and **4h09m**, ending in **Reject**. VS Code was already installed and already renders
> Markdown. That answer was available in 30 seconds. The most expensive audit in this
> repo's history was avoidable by consulting a list that did not exist yet.

**Want this private?** Rename it to `capability-register.local.md` — `*.local.md` is
already git-ignored, and update the link in `02-artifact-triage.md`. A list of what you
run is mild reconnaissance value if you'd rather not publish it.

---

## How to use it

1. **Before** evaluating any new tool, search this file for the **job**, not the tool name.
2. A hit means the disposition is **SUBSTITUTE**. Log one line and go back to work — no
   artifact decision is needed, because the artifact never comes in.
3. A miss means continue to **G1** (classify and forecast).

**Index by job, not by tool.** You will be searching for *"render Markdown"*, not for
*"VS Code"*. One tool may cover several jobs; list it under each.

**Only list tools you actually trust** — things that came through this framework, ship
with the OS, or are long-standing accepted infrastructure. An unvetted tool is not a
substitute; it is another intake.

---

## Register

| Job I need done | Tool I already trust | How it got trusted | Notes / limits |
|---|---|---|---|
| Render / preview Markdown | **VS Code** (built-in preview) | Established dev tooling | Covers the QLMarkdown use case entirely. Also renders in-editor and on GitHub. |
| View Markdown in Finder without opening an app | *(none)* | — | The gap QLMarkdown was meant to fill. **Judged not worth a type-4 intake.** Space-bar preview shows plain text, which has proven sufficient. |
| Monitor / block outbound network connections | **Little Snitch** | Intake review, Accept — [`little-snitch-v6.4.1-intake.md`](little-snitch-v6.4.1-intake.md), updated to 6.5 | Also the observation instrument for Phase 5 runtime reviews. |
| Detect mic / camera activation | **Micro Snitch** | Intake review, Accept with restrictions — [`micro-snitch-v1.6.1-intake.md`](micro-snitch-v1.6.1-intake.md) | Restrictions apply; see report. |
| Inspect code signatures, entitlements, notarization | **`codesign` / `spctl` / `stapler`** (macOS built-ins) | Ships with the OS | Used throughout Phase 4. No intake needed. |
| Detect drift in an already-accepted artifact | [`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh) | First-party to this repo; calibrated 2026-09-15 | Requires a stored `*.baseline.txt`. |
| Rewrite git history / author metadata | **git-filter-repo** (Homebrew) | Fast-lane accept, 2026-07-27 | Core Git-maintainer tool. |

---

## Adding an entry

Add a row whenever an intake ends in **Accept** — that is the moment the tool becomes a
legitimate substitute for future work. Record the **job** in the words you would
naturally search for later, not in the vendor's marketing language.

Also worth recording: jobs you decided **not** to solve (see the Finder-preview row).
A deliberate, reasoned gap is more useful than silence, because it stops you from
re-opening a question you already closed.
