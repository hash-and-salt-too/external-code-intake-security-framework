# Security Audit Framework — Vetting Code You Download from GitHub

A practical, beginner-friendly process for deciding **whether it is safe to download, install, and run something you found on GitHub** — *before* you run it.

This framework applies to **anything you might download from GitHub and execute**, not just "plugins":

- Apps and installers (`.app`, `.dmg`, `.pkg`)
- System add-ons like Quick Look extensions (e.g. **QLMarkdown**), Spotlight importers, kernel/system extensions
- Command-line tools and scripts (shell, Python, Node.js, Ruby, PowerShell)
- Libraries you add to your own projects (npm, PyPI, RubyGems, Cargo, Go modules, Swift Package Manager, CocoaPods)
- Browser extensions and editor/IDE extensions (VS Code, etc.)
- Container images (Docker) and infrastructure code

> **New to this?** Read this page top to bottom, then read [`00-scope-and-boundaries.md`](00-scope-and-boundaries.md) to see what's in and out of scope. Open [`glossary.md`](glossary.md) whenever a word is unfamiliar — every technical term is defined there in plain language. You do not need to be a programmer to use this framework.

---

## The one idea to keep in your head

> **When you run someone else's code, you are giving it the same power you have on your own computer** — to read your files, use your network, and keep running in the background — unless you take specific steps to limit it.

So the real question this framework answers is not *"is this program good?"* It is:

> **"Do I trust this code — and everyone and everything it depends on — enough to give it that power on my machine?"**

That is a **trust decision**, and trust should be *earned with evidence*, not assumed because a project looks polished or has a lot of stars.

---

## The core principles (borrowed from secure engineering)

These five ideas drive every check in this framework. They come straight from the secure-coding standard this workspace follows, re-pointed from "how to write safe code" to "how to safely consume someone else's code."

| Principle | What it means for you as a downloader |
|-----------|----------------------------------------|
| **Assume breach** | Act as if any download *could* be malicious. Design your test so that if it *is* bad, the damage is contained. |
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

STEP 0  Triage: what am I actually downloading?   → 02-artifact-triage.md
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
- [`02-artifact-triage.md`](02-artifact-triage.md) — **start every audit here.** Identify the type of thing you're downloading and get routed to the right checks. *(This is the answer to "does the type of code matter?" — yes, a lot.)*
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
- [`templates/audit-report-template.md`](templates/audit-report-template.md) — fill this in to record your decision.

**Worked example:**
- [`worked-example-qlmarkdown.md`](worked-example-qlmarkdown.md) — the framework applied to QLMarkdown, ready for you to run when you choose.

---

## What this framework is *not*

- **Not a guarantee.** A clean audit lowers risk; it never proves code is safe. A determined, skilled attacker can hide things. The goal is to *raise the cost of fooling you* and to *catch the common cases*, which is the vast majority of real-world bad downloads.
- **Not only automated.** Right now this is documentation and checklists so the whole process is *visible* to you. Once you're comfortable, helper scripts can automate the mechanical parts (hashing, signature checks, dependency scans) — just ask.
- **Not one-and-done.** Re-run the relevant parts whenever you **update** the software. Updates are a common way that a once-trustworthy project turns malicious.

---

## Next step

Open [`02-artifact-triage.md`](02-artifact-triage.md) and identify what you're about to download. It will point you to exactly which phases and checks apply to your case.
