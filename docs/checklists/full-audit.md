# Full Audit Checklist

The complete, phase-by-phase checkbox list. Work top to bottom for any medium/high-risk download (anything that will run with real privileges — installers, system extensions, **QLMarkdown**). Copy the results into the [report template](../templates/audit-report-template.md) as you go.

**Depth guidance:** [`../02-artifact-triage.md`](../02-artifact-triage.md) told you which phases are primary for your artifact type. Do the primary ones thoroughly; do the rest as applicable. **Any dealbreaker → reject (fail closed).**

---

## Step 0 — Triage
- [ ] Identified the **artifact type** (script / build-from-source / pre-built binary / system extension / package library / browser ext / editor ext / container).
- [ ] Determined **which phases** are primary for this type.
- [ ] Chose the **install method** (build from source vs. pre-built vs. package manager) and understand its trade-offs.
- [ ] If considering a source build: ran `scripts/check-build-feasibility.sh` against the selected build file. Treated exit `0` only as **no declared blocker found**, not proof or permission to build; execution still waits for the human decision.
- [ ] If a declared blocker was found: did **not** force the build; retained Phase 3 for readable source; applied Phase 4 to the exact pre-built artifact and Phase 5 according to risk; recorded the missing source↔binary correspondence; used Hold/Reject if uncertainty remained unresolved.
- [ ] If considering an older release: pinned and reviewed that exact version, checked advisories/changelog for later security fixes, and did not use older source as correspondence evidence for a newer binary.

## Phase 1 — Provenance & reputation
> 🔧 [`../../scripts/phase1-provenance.sh`](../../scripts/phase1-provenance.sh) `<owner/repo> --online --tag <tag>` fills in the mechanical rows below. It leaves the judgement rows — arrival path, maintainer credibility, whether to pin newest or older — deliberately unanswered.

- [ ] Confirmed genuine `owner/repo` (no typosquat); reached via a trustworthy link.
- [ ] If a fork: justified using the copy over the original.
- [ ] Reviewed commit **history** (real, spread over time — not a single dump).
- [ ] Checked **recency** of maintenance and **release** history/changelogs.
- [ ] Assessed **contributors** (bus factor) and **issue/PR** activity; issues enabled.
- [ ] Vetted the **maintainer(s)**: account age, track record, cross-referenced identity, no takeover signals.
- [ ] Checked security posture: `SECURITY.md`, `LICENSE`, docs quality, Dependabot/advisories.
- [ ] Searched externally for known malware/security/vulnerability reports.
- [ ] **Pinned the exact version/tag/commit** to audit.

## Phase 2 — Supply chain
> 🔧 [`../../scripts/phase2-supplychain.sh`](../../scripts/phase2-supplychain.sh) `<tree>` covers the deterministic rows offline; add `--online --probe-pins` for the two network questions (can each pinned commit still be retrieved, and does it carry an advisory).

- [ ] Located manifest(s) and listed **direct dependencies**.
- [ ] Checked for a **lockfile** and whether versions are **pinned** vs. floating.
- [ ] Triaged notable/critical dependencies (mini Phase-1 each); flagged forks, random personal repos, typosquats.
- [ ] Reviewed **vendored/bundled** third-party code and submodules; confirmed they match trusted upstream and aren't secretly modified.
- [ ] **Read build/install scripts**: npm `pre/postinstall`, `setup.py`, `build.rs`, `Makefile`/`configure`/`*.sh`, Xcode Run Script phases, `.github/workflows/*`.
- [ ] Confirmed no build step **fetches-and-runs** remote code, decodes hidden blobs, or grabs `sudo`.
- [ ] Cross-checked dependencies against advisory DBs (GitHub Advisories / OSV / NVD).

## Phase 3 — Source code review *(for readable source / build-from-source)*
> 🔧 [`../../scripts/phase3-defaults-vs-docs.sh`](../../scripts/phase3-defaults-vs-docs.sh) `<tree>` pairs each security-relevant default in the code with each "by default" claim in the docs. The rest of this phase is deliberately **not** scripted — the category sweeps below found nothing in the real audit and false-positive badly.

- [ ] Working from the **pinned version** locally; **not** run/built yet.
- [ ] Mapped entry points and where **untrusted input** enters.
- [ ] Searched & reviewed: **network** access · **command/process** execution · **dynamic/remote code** (`eval`, `dlopen`, remote `require`) · **sensitive file** access (`~/.ssh`, Keychain, `~/.aws`, browser data) · **credential/secret** access · **unsafe deserialization** · **persistence** (launch agents, login items, shell rc) · **privilege escalation** (`sudo`, setuid) · **obfuscation**/base64 blobs · **telemetry**.
- [ ] Every risky behavior found maps to a **legitimate, documented** feature.
- [ ] Traced how **untrusted input** is parsed (memory-safety in C/C++; sanitization/escaping of rendered output; remote-resource fetching).
- [ ] If a fork/modified copy: **diffed against upstream** and scrutinized every change.

## Phase 4 — Binary / artifact *(for pre-built downloads)*
> 🔧 [`../../scripts/phase4-artifact.sh`](../../scripts/phase4-artifact.sh) `<bundle>` runs every command below in one pass and can diff the shipped entitlements against the source you reviewed. Expand the archive yourself first with `ditto -x -k`.
>
> ⚠️ The `spctl` row **reaches the network** — measured. Assessing a file in `quarantine/` can signal to a third party that you hold it.

- [ ] Downloaded from the **official Releases** page over HTTPS.
- [ ] **Hash** matches the published SHA-256 (`shasum -a 256`).
- [ ] **Signature** (if provided) valid and from the maintainer's **trusted key** (`gpg --verify`).
- [ ] **Code signing** valid; **Team ID/Authority** matches the vetted maintainer (`codesign --verify …`, `codesign -dv …`).
- [ ] **Notarization/Gatekeeper** accepted; ticket stapled (`spctl -a -vvv …`, `stapler validate`).
- [ ] **Entitlements** reviewed and minimal/sensible for the function; sandbox status noted (`codesign -d --entitlements :-`).
- [ ] Mach-O quick look: `otool -L`, `strings`, `nm` — no surprising URLs/commands/paths.
- [ ] `.pkg`/`.dmg`: inspected **without installing** (`pkgutil --check-signature`, `pkgutil --expand`), and **read pre/postinstall scripts**.

## Phase 5 — Runtime / sandbox
> 🔧 Run [`../../scripts/phase5-kit/00-calibrate.sh`](../../scripts/phase5-kit/00-calibrate.sh) **before installing anything** — it proves each instrument can see a known positive. Then `01-setup.sh` → `02-capture.sh` → `03-check-canary.sh`.

- [ ] Chose an **isolation level** appropriate to risk (separate machine / VM / throwaway user account); backed up real data; no secrets present in the test env.
- [ ] **Monitoring on before running:** outbound firewall (deny-by-default) + `lsof -i`/`nettop`; file activity (`fs_usage`); process spawns (Activity Monitor / `ps`).
- [ ] **Each instrument proved against a known positive** before use — a silent instrument reports "clean".
- [ ] Exercised normally **and** with hostile/malformed input; watched for crashes and unexpected network calls.
- [ ] Checked **persistence** after install: `~/Library/LaunchAgents`, `/Library/Launch*`, login items, `~/Library/QuickLook`, shell rc edits.
- [ ] Searched evidence for the canary in **base64 as well as plaintext** — software that embeds a file usually encodes it, so the plain words never appear.
- [ ] Behavior matches documented function; touches only what it should; no surprise persistence.
- [ ] Uninstalled from the test env and **verified clean removal** (or reverted the VM snapshot).

## Decision & record
- [ ] Findings recorded per phase in the report template.
- [ ] Overall **risk rating** assigned; **go/no-go** decided with rationale.
- [ ] If **go**: installed the exact audited version, kept least-privilege, **pinned** it, and set a plan to **re-audit on updates**.
- [ ] If **no-go**: recorded why (helps future-you and others).

---

Related: [`quick-triage.md`](quick-triage.md) · [`red-flags.md`](red-flags.md) · [report template](../templates/audit-report-template.md)
