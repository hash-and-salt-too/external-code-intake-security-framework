# External Code Intake Security Framework

A practical, beginner-friendly process for deciding **whether externally sourced code is safe to bring into your projects and run on your machine** — *before* you execute, install, or incorporate it. (GitHub is the most common source, but the same thinking applies wherever code comes from — including a package your AI assistant suggests.)

It covers **any external code you might take in**, not just "plugins":

- Apps and installers (`.app`, `.dmg`, `.pkg`)
- System add-ons like Quick Look extensions (e.g. **QLMarkdown**), Spotlight importers, kernel/system extensions
- Command-line tools and scripts (shell, Python, Node.js, Ruby, PowerShell)
- Libraries you add to your own projects (npm, PyPI, RubyGems, Cargo, Go modules, Swift Package Manager, CocoaPods)
- Browser extensions and editor/IDE extensions (VS Code, etc.)
- Container images (Docker) and infrastructure code

The *review thinking* applies to all of these; the hands-on commands currently assume **macOS** (where you run them). See [`00-scope-and-boundaries.md`](00-scope-and-boundaries.md) for the exact scope.

> **New to this?** Read this page top to bottom, then read [`00-scope-and-boundaries.md`](00-scope-and-boundaries.md) to see what's in and out of scope. Open [`glossary.md`](glossary.md) whenever a word is unfamiliar — every technical term is defined there in plain language. You do not need to be a programmer to use this framework.

---

## The one idea to keep in your head

> **When you run someone else's code, you are giving it the same power you have on your own computer** — to read your files, use your network, and keep running in the background — unless you take specific steps to limit it.

So the real question this framework answers is not *"is this program good?"* It is:

> **"Do I trust this code — and everyone and everything it depends on — enough to give it that power on my machine?"**

That is a **trust decision**, and trust should be *earned with evidence*, not assumed because a project looks polished or has a lot of stars.

---

## The core principles (borrowed from secure engineering)

These five ideas drive every check in this framework. They come straight from established secure-coding practice, re-pointed from "how to write safe code" to "how to safely consume someone else's code."

| Principle | What it means for you (bringing code in) |
|-----------|----------------------------------------|
| **Assume breach** | Act as if any incoming code *could* be malicious. Design your test so that if it *is* bad, the damage is contained. |
| **Least privilege** | Give the code the *minimum* access it needs. Test in a throwaway account or VM before trusting it on your main machine. |
| **Defense in depth** | Never rely on a single signal (e.g. "it's popular"). Layer several independent checks. |
| **Zero trust** | Verify every time — including on *updates*. Today's safe version can become tomorrow's compromised one. |
| **Fail closed** | If something can't be verified or looks wrong, the default answer is **no**. Don't install "just to see." |

---

## How to use this framework (you won't always do everything)

Match the depth of your audit to the **risk**. Risk goes up when the code is more powerful, more obscure, and harder to inspect.

```
                 Higher risk  ───────────────────────────►
   Read-only     Runs in a     Runs with your    Runs with admin /
   library in    sandbox        full user         system-level
   a test project (browser ext) privileges        privileges
                                (CLI tool)         (installer, kext,
                                                    Quick Look plugin)
   ── do more of the audit as you move right ──►
```

**Two-speed approach:**

1. **Quick Triage (10–15 min)** — a fast go/no-go using [`checklists/quick-triage.md`](checklists/quick-triage.md). Most sketchy things get rejected here. If it passes *and* the risk is low, you may stop.
2. **Full Audit** — for anything that will run with real privileges on your machine (this includes QLMarkdown), work through all five phases and record the result using [`templates/audit-report-template.md`](templates/audit-report-template.md).

> **Golden rule:** If at any point you can't answer a question and can't find the evidence, treat that gap as a *finding*, not a pass. Unknown = risk.

---

## The process at a glance

```
SCOPE   Is this in scope, and how much review does it need?
        → 00-scope-and-boundaries.md  (external code? risk tier? decision model)

STEP 0  Triage: what am I actually bringing in?   → 02-artifact-triage.md
        (This decides which checks below matter most.)

PHASE 1 Provenance & reputation  → phases/phase-1-provenance.md
        Who made it? Is the project real, active, and trustworthy?

PHASE 2 Supply chain             → phases/phase-2-supply-chain.md
        What does it depend on, and what happens when it's built?

PHASE 3 Source code review       → phases/phase-3-source-review.md
        What does the code actually DO? (network, files, commands)

PHASE 4 Binary / artifact check  → phases/phase-4-binary-artifact.md
        If it's pre-built: is it signed, notarized, untampered?

PHASE 5 Runtime / sandbox test   → phases/phase-5-runtime-sandbox.md
        Watch it run in isolation before trusting your real machine.

DECIDE  Weigh findings, make a go/no-go, write it down.
        → templates/audit-report-template.md
```

---

## Document map

**Read these first (foundations):**
- [`00-scope-and-boundaries.md`](00-scope-and-boundaries.md) — **read first.** What this framework does and doesn't cover, what counts as "external code" (including AI-suggested packages), how much effort a decision deserves, and the decision model.
- [`glossary.md`](glossary.md) — plain-language definitions of every term used here.
- [`01-threat-model-and-principles.md`](01-threat-model-and-principles.md) — what you are defending against, and why.
- [`02-artifact-triage.md`](02-artifact-triage.md) — **start every audit here.** Identify the type of thing you're bringing in and get routed to the right checks. *(This is the answer to "does the type of code matter?" — yes, a lot.)*
- [`03-install-methods-explained.md`](03-install-methods-explained.md) — beginner explainer: "build from source" vs. "pre-built release" vs. "package manager," and why it matters for safety.

**The audit itself:**
- [`04-audit-methodology.md`](04-audit-methodology.md) — how the five phases fit together.
- [`phases/phase-1-provenance.md`](phases/phase-1-provenance.md)
- [`phases/phase-2-supply-chain.md`](phases/phase-2-supply-chain.md)
- [`phases/phase-3-source-review.md`](phases/phase-3-source-review.md)
- [`phases/phase-4-binary-artifact.md`](phases/phase-4-binary-artifact.md)
- [`phases/phase-5-runtime-sandbox.md`](phases/phase-5-runtime-sandbox.md)

**Tools to work with:**
- [`checklists/quick-triage.md`](checklists/quick-triage.md) — the fast go/no-go.
- [`checklists/full-audit.md`](checklists/full-audit.md) — the complete checkbox list.
- [`checklists/red-flags.md`](checklists/red-flags.md) — a catalog of dealbreakers and warning signs.
- [`checklists/phase-5-isolation-setup.md`](checklists/phase-5-isolation-setup.md) — how to actually build the isolated environment Phase 5 assumes (test account, outbound firewall, local listener).
- [`templates/audit-report-template.md`](templates/audit-report-template.md) — fill this in to record your decision.

**Helper scripts** (all read-only — they gather evidence, they never build or run reviewed code):
- [`../scripts/README.md`](../scripts/README.md) — `check-build-feasibility.sh` (can your toolchain even build this?) and `verify-known-artifact.sh` (has an already-audited artifact drifted since you approved it?).
- [`../tools/README.md`](../tools/README.md) — repo maintenance utilities that touch only this repo's own files.

**Worked examples & records:**
- [`worked-example-qlmarkdown.md`](worked-example-qlmarkdown.md) — the framework applied to QLMarkdown, ready for you to run when you choose.
- [`../reports/README.md`](../reports/README.md) — completed intake records, one per target and version.

**Design records (why the framework is the way it is):**
- [`design-decisions.md`](design-decisions.md) — the reasoning behind the scope, the decision model and the two-speed design.
- [`design-decisions-Xcode.md`](design-decisions-Xcode.md) — the dated toolchain record that prompted the build-feasibility helper.

---

## What this framework is *not*

- **Not a guarantee.** A clean audit lowers risk; it never proves code is safe. A determined, skilled attacker can hide things. The goal is to *raise the cost of fooling you* and to *catch the common cases*, which is the vast majority of real-world bad intake.
- **Not mostly automated.** This is deliberately documentation and checklists, so the whole process stays *visible* to you. A few read-only helpers exist in [`../scripts/`](../scripts/README.md) for the mechanical parts, but they only gather evidence — they never decide, and they never run the code under review.
- **Not one-and-done.** Re-run the relevant parts whenever you **update** the software. Updates are a common way that a once-trustworthy project turns malicious. For an artifact you have already audited, [`verify-known-artifact.sh`](../scripts/README.md) turns most of that re-check into a few seconds.

---

## Next step

Open [`02-artifact-triage.md`](02-artifact-triage.md) and identify what you're about to bring in. It will point you to exactly which phases and checks apply to your case.
