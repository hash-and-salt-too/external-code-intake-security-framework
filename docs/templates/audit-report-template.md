# Audit Report Template

Copy this file for each audit (e.g. `reports/qlmarkdown-v1.4.2.md`) and fill it in as you go. Writing findings down forces honesty (gaps become visible) and makes re-auditing updates fast.

> **Fast lane vs. this template:** For a *low-risk* item you may record just a one-line, human-attributed note instead of this full template — see [`../00-scope-and-boundaries.md`](../00-scope-and-boundaries.md). Use this full template for medium/high-risk items, or anything you'll share or publish.

> **How to fill:** For each item record **Result** = ✅ pass · ⚠️ concern · 🛑 dealbreaker · ➖ N/A, plus a short **evidence/note**. An unknown you can't resolve is a ⚠️ or 🛑, never a ✅.

---

## Summary (fill last)

| Field | Value |
|-------|-------|
| **Software** | |
| **Repository** (`owner/repo` + URL) | |
| **Exact version audited** (tag / commit hash) | |
| **Artifact type** (from triage) | |
| **Cost band** (A re-verify · B fast lane · C scheduled · D expensive) | |
| **Install method** (source / pre-built / package mgr) | |
| **Date of audit** | |
| **Reviewer** (you; AI may assist with evidence) | |
| **Overall risk rating** | Low / Medium / High |
| **Cost of rejecting** *(what breaks if the answer is no?)* | e.g. "nothing — VS Code already renders Markdown" |
| **DECISION A — the artifact** | Accept · Accept with restrictions · Reject · Hold (needs a second look) |
| **DECISION B — the task** | Substitute · Work around · Stop+clear (audit ran) |
| **Decision made by** (a human — not the AI) | |
| **One-line rationale** | |
| **Re-audit trigger** | e.g. "any new release," "if entitlements change" |

> **Two decisions, not one.** *Decision A* is about the **artifact** — is it safe? *Decision B* is about the **task you were doing when you hit it** — do you even need this? They are independent: an artifact can be a perfectly good **Accept** that you still choose not to install today. Ask B first; it is usually much cheaper. See [`../02-artifact-triage.md`](../02-artifact-triage.md).

> **Decision model (the artifact):** **Accept** · **Accept with restrictions** (use only under limits you write down — never to wave through a risk you can't explain) · **Reject** (reviewed, not safe) · **Hold — needs a second look** (couldn't resolve something; use/sharing blocked until it is — keeps "I couldn't finish" separate from "it's bad"). Unresolved *high-impact* questions default to blocked (*fail closed*). Resolve a Hold via a safer alternative or a trustworthy community for personal work, or your organization's official channel for work-shared code — never post your organization's material publicly. The AI gathers evidence, but a **human owns the decision.** See [`../00-scope-and-boundaries.md`](../00-scope-and-boundaries.md).

> 🛑 **The path that is not on this list: "install it now, audit it later."** That is not a deferral — it is an **Accept with no evidence**, and it inverts the rule that the gate is on execution. If you ever knowingly choose it, do not record it here: log it in the **`Accepted WITHOUT review`** register so it stays visible until it is resolved.

---

## Step −1 — Disposition (do this FIRST, before any analysis)

The 15-minute budget is for the **decision**, not the **analysis**. Answer these before opening the artifact.

- **G0 — Do I already have a trusted tool that does this job?** *(target: 60 seconds)*
  → If yes, the answer is **Substitute**. Stop. No artifact decision is needed, because the artifact never comes in.
- **G1 — What is it, and what will this cost?** Artifact type, install method, privilege at run time, **does a baseline already exist?**, **does an alternative exist?** → gives the **cost band**.
- **G2 — Compare the forecast to the time I actually have.** → **Substitute** · **Work around** · **Stop+clear**.

*Record the answers even when the result is "stop here" — a 60-second "no" is a real decision and belongs in the log.*

- G0 answer (trusted tool already available?): 
- G1 cost band & why: 
- G2 disposition chosen & why: 
- Time spent reaching the disposition: 

---

## Step 0 — Triage
- Artifact type & why: 
- Primary phases for this type: 
- Chosen install method & trade-off accepted: 
- Build preflight result / selected build file (if applicable):
- Source↔binary correspondence established? If not, why not:
- Older release considered? Exact version and later security fixes checked:

## Phase 1 — Provenance & reputation
| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Genuine `owner/repo`, trustworthy link, fork justified | | |
| Commit history real & spread over time | | |
| Maintenance recency / release history | | |
| Contributors (bus factor) & issue activity | | |
| Maintainer identity & track record; no takeover signs | | |
| Security posture (`SECURITY.md`, `LICENSE`, advisories) | | |
| External reputation search | | |
| **Version pinned** | | |

## Phase 2 — Supply chain
| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Direct dependencies listed | | |
| Lockfile present / versions pinned | | |
| Notable dependencies triaged; no typosquats/odd forks | | |
| Vendored code & submodules match trusted upstream | | |
| Build/install scripts read & benign (no fetch-and-run, no `sudo`, no blobs) | | |
| Dependencies vs. advisory DBs (GH/OSV/NVD) | | |

## Phase 3 — Source review *(if readable)*
| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Network access accounted for | | |
| Command/process execution accounted for | | |
| No dynamic/remote code execution (or justified) | | |
| No sensitive-file/credential access (or justified) | | |
| No unsafe deserialization | | |
| No unjustified persistence mechanisms | | |
| No unjustified privilege escalation | | |
| No obfuscation / hidden payloads | | |
| Telemetry disclosed & proportionate (or none) | | |
| Untrusted-input handling (memory safety / sanitization) | | |
| Fork diff reviewed (if applicable) | | |

## Phase 4 — Binary / artifact *(if pre-built)*
| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Official HTTPS source | | |
| SHA-256 hash matches published | | |
| Signature valid & trusted key (if provided) | | |
| Code signing valid; Team ID matches maintainer | | |
| Notarized / Gatekeeper accepted / stapled | | |
| Entitlements minimal & sensible; sandbox status | | |
| Mach-O quick look (`otool`/`strings`/`nm`) clean | | |
| `.pkg`/`.dmg` inspected w/o installing; scripts read | | |

## Phase 5 — Runtime / sandbox
| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Isolation level used | | |
| Network behavior (destinations contacted) | | |
| File access (only expected paths) | | |
| Process spawning (nothing unexpected) | | |
| Behavior with hostile/malformed input | | |
| Persistence check (launch agents, login items, QL plugins, rc) | | |
| Clean uninstall / snapshot reverted | | |

## Post-install verification *(only if you installed it)*

*These describe **your machine**, not the artifact, so they cannot be baselined — record the figures here instead, because that is the only way a future update can detect a change. Apply the [redaction convention](../../reports/README.md) before committing.*

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Installed copy matches the audited image | | drift check against the recorded baseline |
| **Owner:group of the installed bundle** | | e.g. `root:wheel` — *record the value, not just "ok"* |
| Non-root-owned / group- or world-writable / setuid files | | `--system-ownership` |
| Privileged components declared **inside** the bundle | | system extensions, bundled LaunchDaemons, `SMPrivilegedExecutables` |
| Privileged code installed **outside** the bundle | | `--system-persistence` — a daemon here is **not** covered by the baseline |
| Staged copies match the audited binary; running process traced | | compare *every* staged copy, not just the first |

---

## Findings & open questions
1. 
2. 
3. 

## What this audit did **NOT** check
*Mandatory. A script cannot state what it failed to cover — you must. Name the ceiling of this review honestly: unreviewed code, untested behaviour, phases skipped and why.*
- 

## Dealbreakers encountered (if any)
- 

## Conditions / restrictions if installing
- e.g. keep outbound firewall rule, disable network feature, don't use on machine with work credentials, pin version, review diff on update.

## Decision rationale (the "why," in a few sentences)
> 

## Update log (re-audits of later versions)
| Date | New version | What changed (diff summary) | Re-verdict |
|------|-------------|-----------------------------|-----------|
| | | | |
