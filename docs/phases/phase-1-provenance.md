# Phase 1 — Provenance & Reputation

**Question this phase answers:** *Is this project real, actively maintained, and run by people I have reason to trust?*

This is the cheapest phase and it rejects most bad downloads before you spend effort on anything else. Everything here is done in the GitHub web interface — no tools required.

> **Remember:** popularity is *context*, not proof. The goal is to gather **multiple independent signals**, not to find one green light.

---

## 1.1 Confirm you're at the *real* project

Attackers rely on you grabbing a lookalike. Before anything else:

- [ ] **Check the exact `owner/repo`.** Is the owner who you expect? (For QLMarkdown, the well-known project is `sbarex/QLMarkdown`.) Watch for **typosquats** — `QLMarkdwn`, `QL-Markdown`, `Q1Markdown`, an extra/missing letter.
- [ ] **Check how you got here.** A link from the official docs/homepage is stronger than a random blog, forum post, search ad, or DM. Cross-check the repo URL against the project's official site if it has one.
- [ ] **Beware forks presented as the original.** GitHub shows "forked from …" under the repo name. A fork *can* be legitimate, but ask *why you're installing the copy and not the source.* Malicious forks add a few poisoned lines to otherwise-trusted code.
- [ ] **Watch for freshly renamed/transferred repos.** Ownership changes can mean a project changed hands — sometimes to a bad actor.

> If you can't confirm this is the genuine project, **stop.** *Fail closed.*

---

## 1.2 Read the project's "pulse" (is it real and alive?)

Skim the repo's front page and the **Insights** tab. You're looking for the texture of a genuine, ongoing project versus a hollow shell or a dump.

- [ ] **Commit history depth & spread.** Many commits over months/years from real contributors = healthy. A single massive "initial commit" with no history is a classic sign of code copied in to hide its origin.
- [ ] **Recency.** When was the last commit? Active projects get security fixes. *Abandoned* isn't automatically malicious, but it means bugs won't be patched — a maintenance risk.
- [ ] **Release history.** Are there tagged releases with real changelogs? Steady, documented releases signal discipline.
- [ ] **Contributors.** One person is normal for small tools but is a **bus-factor** risk (and a single point of compromise). Several long-term contributors reviewing each other is stronger.
- [ ] **Issues & pull requests.** Real users filing issues, and maintainers responding, means many eyes on the project. **Disabled issues** on a project asking you to run code is a yellow flag — it removes public scrutiny.
- [ ] **Stars/forks in context.** Useful as corroboration, but remember stars can be bought and popularity attracts attackers. Never treat stars as an audit.

---

## 1.3 Assess the maintainer(s)

Your trust ultimately rests on the people. Spend a few minutes on *who* they are.

- [ ] **Account age & track record.** A years-old account with a history of real projects is more credible than a days-old account that appears only to host this download.
- [ ] **Cross-references.** Does the maintainer have a consistent identity elsewhere (personal site, other well-regarded repos, conference talks, a real name)? Consistency across places is a good sign; a profile that exists *only* to publish this one binary is not.
- [ ] **Responsiveness & tone.** Do they handle bug reports and security questions like a careful engineer? Pressure to "just install it," urgency, or hostility to scrutiny are bad signs.
- [ ] **Recent takeover signals.** A sudden new maintainer, a burst of unusual commits after long silence, or force-pushed/rewritten history can indicate a compromised or sold account.

---

## 1.4 Check the project's security posture

Signals that the maintainers take security seriously:

- [ ] **`SECURITY.md`** — a documented way to report vulnerabilities responsibly.
- [ ] **`LICENSE`** — present and sensible. A real project almost always has one.
- [ ] **Documentation quality** — a clear README that honestly explains what the software does, what permissions it needs, and how it's built.
- [ ] **GitHub security features** — visible use of Dependabot, code scanning, or published **Security Advisories** shows maturity. (Past *advisories* aren't bad — they show issues are found and fixed openly.)
- [ ] **Signed releases / notarization mentioned** — for macOS apps, do the release notes mention notarization or a signing identity? (You'll verify this for real in Phase 4.)

---

## 1.5 Search the project's reputation externally

Five minutes of searching often surfaces known problems:

- [ ] Search `"<project name>" malware` / `"<project name>" security` / `"<project name>" vulnerability`.
- [ ] Check whether it appears in **GitHub Security Advisories**, the **OSV** database, or the **NVD** (National Vulnerability Database). *Having* past CVEs isn't disqualifying — unpatched, ignored ones are.
- [ ] Look for independent discussion (forums, Mastodon/Reddit, blogs) from people who use it. A total absence of any third-party mention for something claiming to be popular is itself odd.

---

## 1.6 Pin the exact version you'll audit

Everything after this phase must target a **specific, unchanging version** — otherwise you audit one thing and run another.

- [ ] Choose a specific **release tag** (e.g. `v1.4.2`) or **commit hash**, not "whatever `main` is today."
- [ ] Record it in your report. From here on, download/clone/inspect *that exact version.*

---

## Phase 1 outcomes

| Result | Meaning | Next |
|--------|---------|------|
| **Clear dealbreaker found** | Fake/typosquat, brand-new throwaway account dumping a binary, disabled scrutiny + pressure to install, evidence of compromise | **Reject.** Stop here. |
| **Serious concerns, no proof** | Obscure, single unknown maintainer, no history, abandoned | Proceed only with heightened scrutiny in later phases; prefer building from source and strict isolation. |
| **Strong, corroborated signals** | Real history, identifiable maintainers, active community, sane docs | Proceed to the phases your artifact type requires. |

Record findings in the [report template](../templates/audit-report-template.md), then continue to [`phase-2-supply-chain.md`](phase-2-supply-chain.md).
