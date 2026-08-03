# Design Decisions & Rationale

*Why this framework is built the way it is — a concise record of the key
decisions and the thinking behind them. Useful for understanding the intent,
onboarding a collaborator, or seeding a new working session with the project's
context.*

---

## Why this exists

It started with a small, real need: a lightweight way to preview Markdown files
without opening a full editor. Vetting one such tool raised a bigger question —
*how do I decide, responsibly, whether any code I find online is safe to run?* —
and that question generalized into this framework.

One tension runs through every decision below: **be responsible without letting
the review become the thing that stops real work.** Each choice balances
security against momentum.

---

## Key decisions

### 1. It's an *intake* framework, not a "plugin audit"
The scope is **anything you'd download, run, install, incorporate, or share from
an outside source** — apps, scripts, libraries, extensions, system add-ons — not
just "plugins." The unit of analysis is *external code*, however it arrives.

### 2. "External code" is defined by provenance, not authorship
It's external if it originated **outside your current project** — regardless of
whether a human or an AI produced it. Code an AI *generates fresh* for your
project is out of scope (though "out of scope" means "not reviewed here," **not**
"proven safe"); code that is *retrieved, copied, or of uncertain origin* is in
scope. **The line is provenance, not effort.**

### 3. One durable, reusable workspace
Not one workspace per target. `docs/` holds the reusable framework (maintained
once); `reports/` holds one record per target + version; `quarantine/` is
read-only staging for code under review.

### 4. Triage by artifact type first
The *type* of thing you're bringing in (script, pre-built binary, package,
system add-on, container, …) drives which checks apply. Identifying the type is
step zero of every review.

### 5. Risk-proportional, two-speed review
Depth scales to risk. Low-risk items ride a **fast lane** (a short structured
triage + a one-line record); higher-risk items get the full phased audit. You
don't run everything on everything.

### 6. "Look before you run" — the keystone
The gate is on **execution, not download**. The safe order is
**propose → pause → fetch for read-only inspection → human decides → then
install / build / run.** Downloading *to read* is fine; installing, building,
executing, or piping fetched code must wait for the decision. This binds AI
assistants too.

### 7. A human owns every decision
An AI may gather and explain evidence, but it must **never** turn uncertainty
into a "yes." Every decision carries a minimum record — one line, attributed to
a person — even in the fast lane.

### 8. A four-outcome decision model (with a lightweight Hold)
**Accept · Accept with restrictions · Reject · Hold.** *Hold* means "I couldn't
resolve something — use and sharing are blocked until it is," kept distinct from
*Reject* ("reviewed, not safe"). Hold is an optional clarity state; unresolved
high-impact questions default to blocked either way (*fail closed*).

### 9. macOS-only, for now
Every command assumes macOS on Apple hardware. The provenance and supply-chain
thinking is platform-agnostic, so other platforms can be added later without a
rebuild.

### 10. Clear boundaries on what a "pass" means
- **Organizational:** a technical pass does **not** authorize use on
  organization-managed hardware, confidential data, or internal networks — those
  need separate organizational processes.
- **Responsibility:** you own what you introduce and publish (at the version you
  ship); changes a downstream forker makes fall outside your review; *updating a
  dependency is a new intake decision.*
- **Lifecycle:** this is an intake gate, not a monitoring program. Approval
  applies only to the exact version reviewed.

### 11. Stress-tested by an independent review
The draft scope was deliberately challenged in a separate "second opinion"
session (using a different AI model, to reduce single-model bias). Its essential
points were folded in: the execution-gate keystone, the Hold state, a structured
quick check instead of an undocumented "mental" one, a better low-risk example,
and wording fixes for confidentiality, downstream responsibility, and AI
provenance. Heavier suggestions — a risk-taxonomy overhaul, a formal evidence
ledger, a continuous-monitoring program, a multi-platform build-out — were
**deliberately deferred** as over-scoped for a solo, beginner, personal-use tool.

### 12. Practicality is a feature, not an afterthought
The framework is intentionally two-speed and beginner-oriented. The governing
principle: *don't let auditing the audit become worse than the risk it manages.*
Refine it from real use, not from endless theory.

---

## How this was developed (provenance)

- **Conceived and directed by the project's author**, who set the intent, made
  every scoping call, and accepted or rejected each recommendation.
- **AI-assisted across two sessions** — a *creation* session and an independent
  *review* session using a different model — to reduce single-model bias.
- Faithful records of those sessions are **retained privately by the author** as
  development history (see the `provenance/` folder); they are intentionally
  excluded from this public repository.

---

## Appendix — Follow-on work records

Use this appendix as the index for durable records of significant work that
extends the project's original creation. Each record should capture the reason
for the work, the process and review used, the resulting decisions or changes,
and relevant validation; add one link and one-sentence summary here when such a
record is created.

- [`design-decisions-Xcode.md`](design-decisions-Xcode.md) — Records the
  Xcode/toolchain feasibility investigation, its cross-model review, and the
  resulting conservative pre-build checks and framework updates.
