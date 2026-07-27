# 00 — Scope & Boundaries

*What this framework is for, what counts as "external code," and how much
effort any one decision deserves.*

Read this first. It sets the boundaries so the rest of the framework stays
focused — and never turns into busywork that gets in the way of your actual
projects.

---

## Purpose

This framework helps you make one careful decision:

> **Before you execute, install, incorporate, or share externally sourced
> code, is it safe enough to bring near your Mac, your data, and your
> projects?**

It exists to reduce the risk that outside code could compromise:

- your Mac and the data, credentials, and networks it can reach;
- colleagues who use or collaborate on the tools you make;
- anyone who clones or forks your public repositories.

It is a **personal intake review** — a "should I let this in?" gate. It is
**not** a commercial-production approval process, and it does not govern code
shipped inside your organization's products.

> **The one idea to keep in your head:** *Checking what you bring in is the
> main thing that also protects everyone downstream of you.* If you don't let
> bad code in, you don't pass it on. Most of this framework is just doing that
> check well, at a depth that matches the risk.

---

## What counts as "external code"

"External" is decided by **where the code came from, not who wrote it** — a
human or an AI. It's external if it originated outside your current project:

- apps, command-line tools, and installers;
- GitHub repositories, forks, and colleagues' projects;
- packages/libraries you add (and the dependencies *they* pull in);
- copied-in ("vendored") libraries and pasted code snippets;
- pre-built binaries and downloaded assets;
- build scripts, installer scripts, and GitHub Actions;
- anything whose origin you can't establish with confidence.

Code your AI assistant **generates fresh for this project** is *out* of scope
here — but "out of scope" means only "not reviewed by *this* intake gate," **not**
"proven safe." It moves *into* scope the moment it **imports an external
package, or includes code that was retrieved, copied, or is of uncertain
origin**. The line is **provenance, not effort**: freshly written = out;
brought in from elsewhere = in.

> **Your most common trigger — read this twice.** For the way you work
> (AI-assisted "vibe coding"), the usual intake event is **not** "I went and
> downloaded a plugin." It's **"my AI assistant just suggested a package, or
> pulled in code from somewhere else."** That is external code, and it's exactly
> the moment to run at least a quick check. This framework is written so that
> this "audit-before-use" step can later be built into project instructions or a
> reusable skill.

---

## In scope / out of scope (for now)

| In scope | Out of scope (for now) |
|----------|------------------------|
| External code you'll run, install, or add to a project **on macOS** | Other platforms (Windows, Linux, cloud/servers) — you're macOS-only for now |
| The technical-security risk of that code | Licensing, attribution, privacy, and org-policy compliance — handled separately, later |
| The exact version/artifact you're about to use | Continuous monitoring after intake — this is an *intake* gate, not a monitoring program |
| Personal tools and public GitHub experiments | Commercial-production / your organization's product code |

**Platform note:** every command in this framework assumes **macOS on Apple
hardware**. If you ever build for another platform, the provenance and
supply-chain thinking still applies, but the specific tools (signing,
notarization, etc.) would need platform equivalents added. The framework is
structured so that can be added later without a rebuild.

---

## Who this is for, and how it's written

You: a **coding beginner doing reviews with AI help**, who wants to be
responsible without stalling real work. So the guidance is:

- concrete and reproducible — plain language, real commands, expected results;
- honest about limits — clear about what a quick or keyword-based check
  *can't* prove;
- explicit about when you've hit the ceiling of beginner-level review.

> **The human decides — not the AI.** Your AI assistant can gather evidence,
> run checks, and explain what it finds. It must **never** turn "I'm not sure"
> into a "yes." Every accept/reject is a decision *you* make and record.

---

## Look before you run (the safe order of operations)

External code can act the **moment you install it** — many installers run
scripts automatically (`npm install`, `pip install`, and friends can execute
code *during installation*, before you ever *use* the package). So the gate is
on **execution, not on merely looking**:

> **The order that keeps you safe:**
> **propose → pause → fetch for read-only inspection → human decides → then
> install / build / run.**
>
> Downloading code *to read it* is fine and often necessary — keep it in the
> `quarantine/` folder, and never build or run from there. What must wait for
> your decision is anything that lets the code *act*: **installing, building,
> executing, or piping fetched code into a shell.**

This applies to your AI assistant too: it may fetch and explain code, but it
must **not install, build, execute, or incorporate** external code until you've
made the intake decision. This is the exact hook that later project instructions
or a skill will enforce.

---

## Right-size the effort (so this never becomes the bottleneck)

Security and convenience always trade off. The way to stay responsible *and*
productive is to **match the depth of review to the risk** — not to run a full
audit on everything.

Risk rises with **power** (what the code can touch), **reach** (who else is
affected), and **how hard it is to inspect**.

| If the code is… | …do this much |
|-----------------|---------------|
| **Low risk** — a well-known library in a personal experiment, sandboxed, easy to read | **Fast lane:** run the short **Quick Triage** checklist, then record a one-line result. (No full audit needed.) |
| **Medium risk** — a tool you'll run locally, or a dependency you'll share with colleagues | Quick Triage, plus the phases that fit the artifact type. |
| **High risk** — installers, system extensions, anything running with real privileges, or code you'll **publish for others to fork** | The **full audit**, with a written report. |

This mirrors the two-speed design in [`README.md`](README.md) and the risk
table in [`01-threat-model-and-principles.md`](01-threat-model-and-principles.md).
Start every decision at [`02-artifact-triage.md`](02-artifact-triage.md) to find
the right depth fast.

---

## The decision model

Every intake ends in one of four outcomes — three conclusions and one "not yet":

| Outcome | Meaning |
|---------|---------|
| **Accept** | Evidence supports it. Use the exact version you reviewed. |
| **Accept with restrictions** | Use it only under stated limits — e.g. "run in a VM only," "block its network access," "not on a machine with work credentials." Write the limits down. Restrictions can contain a *known, bounded* risk; they must **never** be used to wave through a risk you can't explain. |
| **Reject** | You reviewed it and it's not safe to use. |
| **Hold — needs a second look** | *Not a rejection — an "I'm not done."* You've hit something you can't resolve at beginner level, so **use and sharing are blocked until it's resolved.** This keeps "I couldn't finish" separate from "I decided it's bad." |

> **About the "Hold" state — your optional choice (noted so future-you
> remembers).** You added this fourth state deliberately, for clarity. It earns
> its keep by preventing the most common beginner trap: quietly turning *"I'm
> not sure"* into a *yes*. If it ever feels like more ceremony than value, you
> can safely drop it and let unresolved items fall under **Reject** — the
> outcome is the same either way (*fail closed*: when in doubt, don't use it).

**Resolving a Hold** depends on context:

- *Personal projects:* there's usually no one to escalate to — so a Hold
  realistically resolves to **don't use it, pick a safer alternative, or ask a
  trustworthy public community** (mind the confidentiality limit under
  Boundaries).
- *Work / organization-shared:* route it to your organization's
  **security/privacy channel** — never a public forum.

---

## The minimum record (always — even the fast lane)

No decision is invisible. Even a low-risk "yes" gets a **one-line,
human-attributed note**, so there's always a record that *a person* — not the
AI — made the call.

> **Fast-lane minimum:** one line is enough, e.g.
> `2026-07-27 — Accept: tidy-slug v1.2.0 for personal blog script. Small
> pure-JS string helper; no native code, no network; read package.json +
> install scripts. Decided by me (not AI).`
> *(Illustrative example — a small, pure-data library with no native code and
> no network is the kind of thing that genuinely belongs in the fast lane.)*
>
> Higher-risk items use the full
> [report template](templates/audit-report-template.md).

The AI assistant may draft the note and lay out the evidence; **you** confirm
and own it.

---

## Boundaries (so a "pass" doesn't mean more than it should)

**What a pass means.** Passing this review means only that *this external code
cleared a personal technical-security intake check.* It does **not** prove the
code is safe, and it does **not** by itself authorize anything else.

**Organizational boundary (work / managed accounts).** A pass does **not**
authorize running the code on organization-managed hardware, or against
confidential/regulated data, internal networks, org cloud services, or anything
needing elevated privileges. Those require separate organizational processes.
Anything touching privacy, or work outside people's official roles, is a signal
to **escalate through your organization's official channel** rather than decide
solo.

> **Confidentiality when you ask for help.** Asking a public community is fine
> for personal or already-public material — but **never paste your
> organization's code, data, architecture, findings, or screenshots into a
> public forum.** For anything work-related, use approved internal channels
> only.

**Responsibility boundary (forks & downstream).**

- **You own what you introduce and publish** — the specific dependency/snippet,
  at the version you ship. Auditing it before you add or update it is your job.
- **Changes a downstream forker makes on their own copy fall outside the
  evidence and conclusions of your review** — your decision speaks only to the
  version *you* shipped. You stay accountable for that inclusion decision, and
  for not continuing to recommend something once you learn it has a serious
  problem.
- The rule that keeps you honest: **updating or swapping a dependency is a
  *new* intake decision.** That's the safeguard against "I bumped a library
  without checking and shipped it."

**Lifecycle boundary.** This is an **intake** gate. Approval applies only to the
**exact version or immutable artifact** you reviewed. Adopting an update, or a
materially different fork, is a new decision that needs its own review. You are
not signing up for ongoing monitoring of personal projects — just a good-faith
check each time something new comes in or changes.

---

## How this connects to the rest of the framework

- Start any decision at [`02-artifact-triage.md`](02-artifact-triage.md) — it
  routes you to the right depth and phases.
- The [`phases/`](phases/) do the actual checking; the
  [`checklists/`](checklists/) give you the fast and full versions.
- Record results with the
  [report template](templates/audit-report-template.md) (or a one-liner for the
  fast lane).
- Longer term, this scope is meant to feed **project instructions or a reusable
  skill** that enforces "audit-before-use" whenever external code — including an
  AI-suggested package — enters a project.
