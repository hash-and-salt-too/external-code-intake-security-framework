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
| **Install method** (source / pre-built / package mgr) | |
| **Date of audit** | |
| **Reviewer** (you; AI may assist with evidence) | |
| **Overall risk rating** | Low / Medium / High |
| **DECISION** | Accept · Accept with restrictions · Reject · Hold (needs a second look) |
| **Decision made by** (a human — not the AI) | |
| **One-line rationale** | |
| **Re-audit trigger** | e.g. "any new release," "if entitlements change" |

> **Decision model:** **Accept** · **Accept with restrictions** (use only under limits you write down — never to wave through a risk you can't explain) · **Reject** (reviewed, not safe) · **Hold — needs a second look** (couldn't resolve something; use/sharing blocked until it is — keeps "I couldn't finish" separate from "it's bad"). Unresolved *high-impact* questions default to blocked (*fail closed*). Resolve a Hold via a safer alternative or a trustworthy community for personal work, or your organization's official channel for work-shared code — never post your organization's material publicly. The AI gathers evidence, but a **human owns the decision.** See [`../00-scope-and-boundaries.md`](../00-scope-and-boundaries.md).

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

---

## Findings & open questions
1. 
2. 
3. 

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
