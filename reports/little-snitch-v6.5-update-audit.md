# Update Audit — Little Snitch 6.4.1 → 6.5

> **Status: complete.** Audited, accepted, installed and post-install verified on
> 2026-09-15. Superseded 6.4.1 system extension awaits removal on next reboot.
>
> **This is an UPDATE/DIFF audit, not a first intake.** It asks one question:
> *did the trust anchor or the privilege change?* It is **not** a re-audit, and a
> clean result is **not** permission to install.
>
> **Result key:** ✅ pass · ⚠️ concern · 🛑 dealbreaker · ➖ N/A or out of scope.
> An unknown that can't be resolved is a ⚠️ or 🛑 — never a ✅.

This was the framework's **first update audit**. The workflow it defines is written
up in [`../docs/05-update-audit.md`](../docs/05-update-audit.md).

---

## Summary

| Field | Value |
|-------|-------|
| **Software** | Little Snitch — macOS outbound application firewall & network monitor |
| **Baseline version** | 6.4.1 (build 7212), accepted 2026-08-05 — [`little-snitch-v6.4.1-intake.md`](little-snitch-v6.4.1-intake.md) |
| **New version** | **6.5 (build 7303)**, released 2026-09-08 |
| **DMG SHA-256** | `a83763bbf416676231bcd9c414b16a36c31cc85c14aa0de43cabaf1ef97fa8ba` (38,377,961 bytes) |
| **App CDHash** | `b2a7c80a33562961e72caaeb39d236ba7831bed2` *(6.4.1 was `642f3ccb…`)* |
| **Artifact type** | Type 4 — system extension. **Cost band A (re-verify)**, because a baseline existed |
| **Trigger** | Re-audit trigger from the 6.4.1 intake: *"any new version"* |
| **Date** | 2026-09-15 |
| **Reviewer** | Repo maintainer (human). AI assistant gathered and explained evidence only. |
| **DECISION A — the artifact** | 🟢 **ACCEPT** |
| **DECISION B — the task** | **Install 6.5 now** (performed by the human; the assistant installs nothing) |
| **Decision made by** (a human — not the AI) | **Repo maintainer (human), 2026-09-15.** The AI made no accept/reject determination. |
| **One-line rationale** | Trust anchor, privilege, entitlements, component list and linkage are provably unchanged from an accepted baseline, verified with an instrument calibrated against known positives and known negatives. |
| **What informed the decision** | The human's Accept was **informed by AI analysis** that this `.x` update appears benign — no drift, no new privilege, no new linkage — and that it offers a concrete benefit in the **encrypted-DNS fixes**. The AI gathered and explained that evidence; it issued no verdict. |
| **Re-audit trigger** | Unchanged: any new version; any release claiming `packet-tunnel-provider` or `app-proxy-provider`; any change of Team ID from `MLZF7K7B5R`. Re-verify against [`little-snitch-v6.5.baseline.txt`](little-snitch-v6.5.baseline.txt). |

**Active time: 25m18s** (09:27:49 → 09:53:07). Instrument calibration, **6m01s**,
excluded as one-time cost — see *Measurement* below.

> **Chronology, because the section order below is logical rather than temporal.**
> Calibration (Part 2) actually ran **first**, 09:21:48 → 09:27:49, *before* the audit
> clock started. The disposition (Part 1) then ran 09:27:49 → 09:31:40. Parts are
> numbered by role, not by sequence.
>
> **The install is not in the 25m18s.** Installation, the failed Finder attempt, the
> recovery and the post-install verification all happened *after* the clock stopped and
> were **not measured**. Treat 25m18s as the cost of *reaching a decision*, not of
> putting the update into production.

---

## Part 0 — Pre-commitment (recorded before any evidence was gathered)

Following the practice that made the QLMarkdown decision defensible: the escalation
criteria were fixed **before** looking at the artifact, so the outcome could not be
rationalised after the fact.

**Any of these would have forced a full re-audit and a "do not install":**

- Team ID different from `MLZF7K7B5R`
- Any new entitlement on any component
- `packet-tunnel-provider` or `app-proxy-provider` appearing
- Any non-Apple linked library appearing (6.4.1 had zero)
- Loss of `flags=0x12b00` on any component
- Notarization or Gatekeeper regression **on the app**

**Time forecast, pre-committed:** 12–25 minutes.
**Hypothesis under test:** update cost < ~25% of first-contact cost.

---

## Part 1 — Disposition (the task decision), 3m51s

The framework now asks the task question **before** the artifact question.

| Gate | Finding |
|------|---------|
| **G0 — do I already have a trusted tool for this job?** | **Yes — Little Snitch 6.4.1**, already audited, accepted, and running. For an update, SUBSTITUTE and WORK AROUND collapse into a single answer: *stay on the version already cleared.* |
| **G1 — cost band** | Type 4 would normally be band D (4h+). **A baseline existed → band A.** |
| **G1 — is the upgrade pressure real?** | **No.** Host is macOS 15.7.9. The vendor's "upgrade before macOS 27 Golden Gate" warning is conditional on an OS upgrade not yet made. |
| **G1 — security fixes claimed?** | **None.** No CVE, no advisory. Encrypted-DNS changes are described as bug fixes. |
| **G1 — new risk introduced?** | **Yes, mild.** "Added an experimental implementation of NAT64 (RFC 6052)" — experimental code in the packet path of a network filter. |
| **G2 — forcing function** | Updater checks daily (`SoftwareUpdateCheckAutomatically = 1`, interval 86400; last check 2026-09-14 23:11:55 UTC — six days after 6.5 shipped, so it has already seen it). No auto-install key was **set** in that domain. ⚠️ *Inference, not observation:* that an unset key means "prompts rather than replaces silently" was **never tested**, and an unset key says nothing about the built-in default. Recorded as an assumption. |

**Disposition chosen: STOP+CLEAR.** Recorded honestly: on the production merits alone
the cheaper defensible answer was WORK AROUND (no security fix, no compatibility
pressure). STOP+CLEAR was chosen to exercise and define the update workflow.

---

## Part 2 — Instrument calibration (mandatory, 6m01s)

[`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh) had
**never been run against a real update**. Per the tripwire rule — *if this check is
broken, what does its output look like?* — a "no drift" result from an uncalibrated
comparator is indistinguishable from a comparator that read nothing. Calibration was
therefore run first.

| # | Test | Expected | Result |
|---|------|----------|--------|
| N | Installed 6.4.1 vs its own stored baseline | no drift, exit 0 | ✅ no drift in 2.5s |
| P1 | A different app entirely (`iA Writer Classic`) | gross drift | ✅ **every detector fired**: 56 CHANGED · 14 NEW PRIVILEGE · 12 NEW NON-APPLE LIBRARY · 29 DROPPED PRIVILEGE · 2 IDENTIFIER CHANGED · 8 ADDED / 10 REMOVED components |
| P2 | Baseline copy with one entitlement removed | **NEW PRIVILEGE** | ✅ detected `endpoint-security.client` exactly |
| P3 | Baseline copy with Team ID altered | teamid + authority drift | ✅ detected |
| P4 | Baseline copy with non-Apple libs removed | new library flagged | ➖ **no-op — 6.4.1 has zero non-Apple libraries** |
| P5 | `--record` against apps that *do* link non-Apple libs | non-zero counts | ✅ 12 / 8 / 30 lines — collector works |

> ⚠️ **Correction, added during QA of this report.** An earlier draft called P4 "the most
> important calibration result" and claimed the non-Apple-library detector *"could not be
> exercised by this artifact at all."* **That was an overclaim.** Re-reading P1's output
> in full — rather than through the `head -25` that truncated it during the run — shows
> P1 produced **12 `NEW NON-APPLE LIBRARY` lines**, so the detector was already proven to
> fire. P4 was a no-op *in isolation*; P5 was confirmatory, not gap-closing.
>
> The residual point still stands and is worth keeping: **Little Snitch's own zero could
> not have validated that path**, so had P1 not been run, a broken `otool` parser and a
> genuinely clean app would have been indistinguishable. The lesson is real; the
> dramatisation was not. **Truncating a command's output is what caused the error** —
> now logged as friction item 7.

**P2 is the trigger that matters most** — "a new entitlement appeared" is the single
most important escalation criterion, and it is now proven to fire.

---

## Part 3 — Evidence

Release notes were read **before** the binary, so the artifact could be checked against
the vendor's claims rather than the claims being used to explain away the artifact.

### Provenance

| Check | Result | Evidence |
|-------|:------:|----------|
| Official download path | ✅ | URL taken from the vendor's own download page, not guessed: `https://www.obdev.at/downloads/littlesnitch/LittleSnitch-6.5.dmg` → redirects to `/ftp/pub/Products/littlesnitch/`. **Same redirect pattern the 6.4.1 audit recorded as benign** — a consistency check passing. |
| Size matches advertised | ✅ | `Content-Length: 38377961` = downloaded 38,377,961 bytes exactly. |
| Publication timing | ✅ *(noted)* | Signing timestamp **Sep 4 2026 05:08:16** matches HTTP `Last-Modified` **Sep 4 2026 12:08:16 GMT** exactly (same instant, different zone) — two independent sources agreeing. Announced release date is **Sep 8**, a 4-day build-then-announce gap. Benign, recorded. |
| Quarantine xattr | ➖ | `com.apple.provenance` only. Expected: a `curl` fetch does not set `com.apple.quarantine`. |

### Trust anchor

| Check | Result | Evidence |
|-------|:------:|----------|
| DMG signature valid | ✅ | `valid on disk`, `satisfies its Designated Requirement`. **Verified before mounting.** |
| Signing identity | ✅ | `Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)` → `Developer ID Certification Authority` → `Apple Root CA`. Identical chain to 6.4.1. |
| Vendor designated-requirement check | ✅ | `codesign --verify -R="anchor apple generic and certificate leaf[subject.OU] = MLZF7K7B5R"` → exit 0. Team ID carried forward from the prior audit, so this is a genuine cross-version check. |
| App notarized / stapled / Gatekeeper | ✅ | `stapler validate` → *worked*; `spctl -a -vvv` → **accepted, source=Notarized Developer ID**. |
| **DMG wrapper notarized** | ⚠️ | **Still not notarized.** `does not have a ticket stapled`; `spctl` → *rejected, Unnotarized Developer ID*. Identical to 6.4.1 finding #1. |
| Team ID uniformity | ✅ | Single Team ID across all 10 components: `MLZF7K7B5R`. |

### Drift check — the core of an update audit

```
scripts/verify-known-artifact.sh \
  --baseline reports/little-snitch-v6.4.1.baseline.txt \
  "/Volumes/Little Snitch 6.5/Little Snitch.app"
```

**Result: ✅ No drift. Every recorded invariant still holds. 10 components. Exit 0. Elapsed 6 seconds.**

**Proof the instrument actually read 6.5** (a clean result is only meaningful if the
comparator saw new bytes):

| Component | 6.4.1 CDHash | 6.5 CDHash | |
|---|---|---|:--:|
| `Little Snitch` | `642f3ccb…` | `b2a7c80a…` | ✅ differ |
| `…networkextension` | `985829c3…` | `b8b5bae3…` | ✅ differ |
| `…endpointsecurity` | `1e3e5f1b…` | `8c85ea40…` | ✅ differ |

> The 6.4.1 value `642f3ccb609fffcfbd2a548fddd46e8b3c87df49` matches the CDHash
> recorded in the 6.4.1 intake report exactly — independently confirming that the
> installed app really is the artifact that was audited.

**Every binary changed; not one invariant did.** That is the ideal shape for a point
release from a disciplined vendor.

### Privilege

| Check | Result | Evidence |
|-------|:------:|----------|
| Entitlements unchanged | ✅ | 29 entitlement lines, identical set to 6.4.1. |
| Declared vs Apple-authorized | ✅ *(notable)* | Provisioning profiles authorize `networking.networkextension` **and `keychain-access-groups`**; the shipped binaries claim **no keychain access at all**. The narrower-than-authorized property from 6.4.1 is retained. |
| NE capabilities claimed | ✅ | `content-filter-provider`, `dns-proxy` — unchanged. |
| `packet-tunnel-provider` / `app-proxy-provider` | ✅ | **Absent.** Pre-committed triggers did not fire. |
| Dangerous entitlements | ✅ | `get-task-allow`, `disable-library-validation`, `allow-unsigned-executable-memory`, `allow-dyld-environment-variables`, `com.apple.private.*` — all absent. |
| Hardened runtime & flags | ✅ | `0x12b00` on all 10 components (hardened + kill + restrict + library-validation). |
| Non-Apple linked libraries | ✅ | **0**, unchanged. A raw `otool -L` on the main binary listed **56** libraries (57 output lines, the first being the file-path header), every one Apple-supplied — confirming the tool genuinely ran rather than returning nothing. |
| Component list | ✅ | 10 components, unchanged. |

### Handling

| Check | Result | Evidence |
|-------|:------:|----------|
| Image handled without executing | ✅ | `hdiutil attach -readonly -nobrowse -noautoopen`; all internal CRC32s verified on attach; detached cleanly (`"disk10" ejected`). Nothing installed, launched, or moved to `/Applications` during the audit. |

---

## Decision rationale

**Decision A — Accept the artifact.** The evidence is unusually strong for how little
it cost: identity, integrity and privilege are all provably unchanged against a
baseline recorded at the previous audit, and the comparison was made with an
instrument that had first been shown to detect a deliberately introduced entitlement,
a deliberately altered Team ID, and a wholly different application. Every binary in the
bundle changed while not one invariant did — the expected shape of a legitimate point
release from a vendor with mature signing discipline.

The human's Accept was **informed by AI analysis** that this `.x` update appears benign
and carries a real benefit: the **encrypted-DNS fixes**. DNS encryption is a privacy
feature actively relied on, and "improved and fixed various aspects of encrypted DNS"
is a direct improvement to it. The assistant gathered and explained that evidence and
explicitly framed both sides; **the determination was the human's**.

**Decision B — install now.** Weighed against the two arguments for waiting — no claimed
security fix, and a newly added *experimental* NAT64 implementation — the human judged
the encrypted-DNS benefit and being current ahead of any macOS 27 move to outweigh
them. Recorded openly: this is a **preference-weighted call, not an evidence-forced
one**. The evidence supported either disposition. Finding 4 (experimental code in the
packet path) remains an open, accepted risk rather than a resolved one.

---

## Findings

1. **Zero drift across a feature release.** Every binary changed; no invariant did.
   Verified with an instrument calibrated against both known positives and a known
   negative, and cross-checked by CDHash to prove it read the new bytes.

2. **The unnotarized DMG wrapper is systemic, not anomalous.** 6.4.1 finding #1
   recurs identically in 6.5. Two consecutive releases make this a stable vendor
   packaging practice rather than a one-off mistake — which is *less* alarming than a
   wrapper whose notarization status changed between releases. The practical
   consequence is unchanged: offline verification of the container is impossible.

3. **No security fixes are claimed in 6.5.** This is the strongest argument that the
   update was not urgent, and on the evidence alone the cheaper disposition was
   WORK AROUND. The human installed anyway, on the encrypted-DNS benefit and currency
   ahead of a future macOS 27 move — recorded in *Decision rationale* as a
   preference-weighted call rather than an evidence-forced one. Both facts stand
   together; neither cancels the other.

4. **Experimental code was added to the packet path.** "An experimental implementation
   of NAT64 (RFC 6052)" in a product that sits in the network filter path. Not a
   dealbreaker and not detectable by any drift check — recorded because a drift check
   is structurally blind to behaviour, and "experimental" is the vendor's own word.

5. **The baseline does not cover the code that actually runs.** The privileged
   extension executes from a macOS-staged copy at
   `/Library/SystemExtensions/<UUID>/`, and the daemon from
   `/Library/Application Support/Objective Development/Little Snitch/Components/` —
   not from `/Applications/Little Snitch.app`, which is what the baseline records.
   For 6.4.1 the staged binary was confirmed **byte-identical**
   (`79157dba1021d2a7…`) to the one inside the app — but that was *verified, not
   assumed*, and the drift check does not cover it by default. **This is the most
   important structural finding of the run** and it is now a required step in the
   update workflow.

   **Confirmed twice more after this finding was written.** (a) When the failed Finder
   install destroyed the `/Applications` bundle, the firewall kept filtering normally
   — the running code was untouched because it lives elsewhere. (b) After a successful
   install, the 6.5 staged copy `<staged-uuid-6.5>` was verified byte-identical (`9aac886e…`)
   to the audited app's extension, and the running process was traced to that exact
   UUID. Static inference, accidental demonstration, and deliberate verification all
   agree.

6. **The release notes duplicate a 6.4 item.** "App bundle integrity monitoring" is
   described in both the 6.4 and 6.5 notes in nearly identical wording. Benign vendor
   documentation drift; recorded only because release notes are being used as evidence.

7. **Finder is an unsafe installer for a system-extension app, and it fails
   destructively.** It deleted the existing bundle and then could not write the
   replacement, leaving a 1-file husk that no longer verified. It named no files in its
   error dialog, so the failure was undiagnosable from the UI alone. For a `root:wheel`
   bundle hosting a registered system extension, the correct tool is `ditto` — already
   mandated in Phase 4 over `unzip` for the same reason: it preserves signing metadata.

8. **🔑 `sudo ditto` silently transferred ownership of a security tool to an unrelated
   local user account.** `ditto` run as root preserves the *source* UID numerically. The
   vendor's DMG carries **uid 504** from Objective Development's build machine; on this
   host 504 resolved to a **real, login-capable account in the `admin` group**. The
   firewall's bundle therefore became modifiable by that account without
   `sudo`, where it had previously been `root:wheel`. Remediated with
   `sudo chown -R root:wheel`, which does not disturb the code signature.

   **This is the most instructive failure of the whole run.** Every check available at
   the time passed — signature valid, notarization intact, Gatekeeper accepted, drift
   clean, binaries byte-identical to the audited image — and a genuine local privilege
   regression still passed through all of them, because **the baseline schema records
   signing invariants but not POSIX ownership or permissions**. The instrument answered
   its own question correctly and its honest "no drift" concealed a change it is
   structurally incapable of seeing. That is the tripwire failure mode in a new place:
   not a broken check, but a **correct check mistaken for a complete one**.

   **Now addressed — but not by extending the schema, which would have been wrong.**
   Ownership cannot be a baseline record: a baseline must contain only facts that travel
   with the artifact, and ownership is assigned at install time. The same image was read
   as uid 502 by a normal user and uid 504 by root during this session, so a baselined
   figure would capture a *reading artifact* and would break every image-to-installed
   comparison. A new `--system-ownership` mode instead reports installed ownership,
   writability and setuid state, and weighs it against the privileged components the
   bundle carries — because non-root ownership only matters when the bundle holds code
   that runs with more authority than the account able to rewrite it.

   **Three limits are stated rather than papered over:** it reports *state, not change*
   (so the figure must be recorded here to be useful later); it counts only
   **bundle-declared** privileged components, so it inherits finding 10's blind spot and
   must be paired with `--system-persistence`; and it refuses to run against a mounted
   image rather than returning a confident wrong answer.

9. **A glob plus `head -1` silently compared the wrong file.** The first verification
   attempt hashed the *old* staged extension because `/Library/SystemExtensions/*/`
   matched two UUIDs and the script took the first. It reported a mismatch against a
   correctly-installed system. Same class as finding 8: the tooling was not broken, it
   was answering a subtly different question than the one asked. Fixed by iterating over
   **every** staged copy and identifying which one the running process actually uses.

10. **🔑 Persistence was never actually enumerated — in this audit *or* the 6.4.1 one.**
    The 6.4.1 intake report listed three launchd plists
    (`at.obdev.littlesnitchd.plist`, `at.obdev.LittleSnitchHelper.plist`,
    `at.obdev.LittleSnitchUIAgent.plist`) and marked the row ✅. **None of the three
    exists anywhere on the system.** They are 3.x/4.x-era names carried in from the
    vendor's CVE history — a *historical* detail written into a *current-state*
    inventory and given the same confidence as observed evidence. Corrected in that
    report with the error preserved.

    The **actual** persistence, enumerated post-install and unchanged from 6.4.1:

    | Job | Program | Covered by baseline? |
    |---|---|:--:|
    | `/Library/LaunchAgents/at.obdev.littlesnitch.agent.plist` | …`/Applications/Little Snitch.app/Contents/Components/…` | ✅ inside the bundle |
    | `/Library/LaunchDaemons/at.obdev.littlesnitch.daemon.plist` | …`/Library/Application Support/Objective Development/…` | ⚠️ **outside** |

    **The root daemon — the component that runs as `root` at every boot — loads from a
    path the baseline has never covered.** This is the same structural gap as finding 5,
    in a more privileged place: finding 5 concerns a staged *copy* of an audited binary,
    whereas this is a binary that was never inside the audited bundle at all.

    Now automated: `persistence` and `privileged-helper` records were added to the
    baseline schema (**schema 2**), and a `--system-persistence` mode enumerates
    installed launchd jobs and flags any whose program lies outside the bundle. The
    6.5 baseline was re-recorded at schema 2; because Little Snitch declares no bundled
    launchd jobs, its records are unchanged — a zero that was **only trustworthy after
    the collector was calibrated against apps that do declare them.**

---

## What this audit did **NOT** check

Mandatory section. A drift check answers one narrow question; everything below is
outside it.

- **Behaviour.** Nothing was run. A drift check cannot detect a malicious change that
  keeps the same Team ID, entitlements and component list — which a compromise of the
  vendor's own build pipeline would.
- **POSIX ownership and permissions.** Deliberately **not** a baseline record — see
  finding 8 for why baselining it would be wrong rather than merely absent. Covered
  instead by `--system-ownership`, which reports *state, not change*, and which counts
  only **bundle-declared** privileged components. Neither it nor `--system-persistence`
  is sufficient alone.
- **The new NAT64 code.** Closed source; not reviewable, not exercised.
- **The Software Update component.** Still the ongoing trust dependency identified in
  the 6.4.1 audit: it can replace this artifact with one that was never reviewed.
- **The staged/installed copies** were **not** covered by the audit itself. They were
  verified separately *after* installation — every staged copy enumerated, and the
  running process traced to a specific UUID. See the install section.
- **Phases 2, 3 and 5** — out of scope for the same structural reasons recorded in the
  6.4.1 intake (closed source; self-observation is circular; a system extension cannot
  be meaningfully sandboxed).
- **Whether the update was *necessary*.** It was not, on the evidence — see finding 3.
  It was installed on a preference-weighted judgement, recorded as such.

---

## Install & post-install verification (owed, because Decision B was "install now")

The install is performed by the human; the assistant installs nothing. Full procedure in
[`../docs/05-update-audit.md`](../docs/05-update-audit.md) Steps 8–9.

**The requirement is an unbroken chain: audited bytes → installed bytes.**

> 🛑 **Little Snitch's own "Check for Updates" must not be used for this install.** It
> would re-download 6.5 — a different acquisition from the one audited, producing a file
> never hashed against this report. The audited artifact is the local copy whose SHA-256
> is `a83763bb…`.

**Pre-update state recorded** (for proving the staged extension actually changed):

| | |
|---|---|
| Installed version | 6.4.1 (build 7212) |
| Staged extension UUID | `<staged-uuid-6.4.1>` *(redacted — per-install value)* |
| Audited DMG SHA-256 | `a83763bbf416676231bcd9c414b16a36c31cc85c14aa0de43cabaf1ef97fa8ba` |
| Expected post-update | 6.5 (build 7303), **new** staged UUID |

Both of these must pass before the update is considered closed:

```bash
# 1. The installed app must match the image that was audited.
scripts/verify-known-artifact.sh \
  --baseline reports/little-snitch-v6.5.baseline.txt \
  "/Applications/Little Snitch.app"

# 2. macOS re-stages the system extension under a NEW UUID on update.
#    The staged copy must match the one inside the audited app (finding 5).
shasum -a 256 \
  "/Applications/Little Snitch.app/Contents/Library/SystemExtensions/at.obdev.littlesnitch.networkextension.systemextension/Contents/MacOS/at.obdev.littlesnitch.networkextension" \
  /Library/SystemExtensions/*/at.obdev.littlesnitch.networkextension.systemextension/Contents/MacOS/at.obdev.littlesnitch.networkextension
```

### What actually happened — the install did not go to plan

**The Finder drag-install failed destructively.** Dragging the app from the mounted
image onto `/Applications` produced *"The operation can't be completed because some
items had to be skipped"*, and the dialog named no items. Finder had authenticated far
enough to **delete the existing bundle** but could not write the replacement from the
read-only image. `/Applications/Little Snitch.app` was left containing exactly **one
file** — `Contents/CodeResources`, 4 KB — with `codesign` reporting *"bundle format
unrecognized, invalid, or unsuitable"*.

> 🟢 **Network protection never lapsed — an unplanned live confirmation of finding 5.**
> With the `/Applications` bundle destroyed, `systemextensionsctl` still reported
> `at.obdev.littlesnitch.networkextension (6.4.1/7212) [activated enabled]`, all three
> privileged processes remained alive, and outbound HTTPS resolved normally. The filter
> runs from `/Library/SystemExtensions/<UUID>/`, entirely independent of the app bundle.
> Finding 5 predicted this from static evidence; the accident demonstrated it.

**Recovery** was `sudo rm -rf` of the gutted remnant followed by `sudo ditto` from the
same read-only image — preserving the audited-bytes chain, since the source was the
artifact already verified in this report.

### Verified outcome

| Check | Result |
|---|:--:|
| Installed version | ✅ 6.5 (build 7303), 518 files, 156 MB |
| Signature after install + `chown` | ✅ valid on disk, satisfies its Designated Requirement |
| Drift vs audited 6.5 baseline | ✅ **No drift**, 10 components |
| Notarization / Gatekeeper | ✅ stapled; accepted, `source=Notarized Developer ID` |
| Ownership | ✅ `root:wheel`, **0** non-root-owned files *(after remediation — see finding 8)* || Ownership vs privilege (`--system-ownership`) | ✅ | 599 files, all `root:wheel`; 0 group/world-writable; 0 setuid/setgid; **2 system extensions present and not rewritable by a non-root account** || System extension swapped | ✅ 6.4.1/7212 → **6.5/7303 `[activated enabled]`** |
| Old extension | ✅ `[terminated waiting to uninstall on reboot]` |

**The full chain, verified link by link:**

| Link | SHA-256 |
|---|---|
| Audited extension binary (in the image) | `9aac886e…` |
| Staged copy `<staged-uuid-6.5>` (v6.5) | `9aac886e…` ✅ |
| **Running process** | executes from `<staged-uuid-6.5>` ✅ |
| Superseded `<staged-uuid-6.4.1>` (v6.4.1) | `79157dba…`, pending removal on reboot |

**audited bytes == installed bytes == staged bytes == running bytes.**

> ℹ️ **The silent extension swap was correct behaviour, not a failure.** This report
> initially anticipated an authentication prompt. macOS requires user approval only on a
> system extension's **first** activation or when its **Team ID changes**; a same-team
> version update is replaced silently. The expectation was wrong — and the right response
> was the one taken: **verify that the version actually changed** rather than read the
> silence either way. Silence is exactly the signal the tripwire rule says never to trust.

**Outstanding:** a reboot will remove the superseded 6.4.1 extension. Not required for
correct operation; until then two staged copies coexist and only `<staged-uuid-6.5>` is active.

### Persistence, enumerated from the system

Run with `--system-persistence` (added during this audit — see finding 10). **Unchanged
across the update**, and enumerated rather than recalled:

| Job | Label | Scope |
|---|---|---|
| `/Library/LaunchAgents/at.obdev.littlesnitch.agent.plist` | `at.obdev.littlesnitch.agent` | ✅ program inside the audited bundle |
| `/Library/LaunchDaemons/at.obdev.littlesnitch.daemon.plist` | `at.obdev.littlesnitch.daemon` | ⚠️ program **outside** the bundle, in `/Library/Application Support/…` |

No job was added, removed or relabelled by the update. The bundle itself declares **no**
`SMAppService` launchd jobs and **no** `SMPrivilegedExecutables`; persistence is written
to `/Library` by the app at install time instead.

---

## Measurement — testing the front-loaded-cost hypothesis

| Segment | Time |
|---|---|
| Instrument calibration *(one-time, excluded)* | **6m01s** |
| G0–G2 disposition | 3m51s |
| Release notes, URL resolution, download, pre-mount verification | ~9m |
| Mount, drift check, instrument proof, privilege checks, detach | ~12m |
| **Total active audit** | **25m18s** |
| *of which: the drift comparison itself* | **6 seconds** |

**Pre-committed forecast: 12–25 minutes. Actual: 25m18s** — marginally over. Recorded
as a miss rather than rounded down.

> ⚠️ **Two human-side distortions inflate this number, in fairness to the method.**
> The reviewer **manually approved every tool permission request** during the run, each
> one interrupting an in-flight command, and was simultaneously **multi-tasking at a
> nearby computer**. Neither is a cost of the *framework*; both are costs of *how this
> particular session was operated*. They are recorded rather than subtracted, because
> the log's value depends on never quietly flattering the result — but the underlying
> method is faster than 25m18s implies, and an uninterrupted run with pre-granted
> permissions would land meaningfully lower.

**Hypothesis: update cost < ~25% of first-contact cost.**

No timed first-contact figure exists for Little Snitch 6.4.1 (it was audited during
the QLMarkdown gap, off-clock). The closest honest proxy is QLMarkdown's comparable
depth, **P1 + P4 = 1:29:07**. Against that, 25m18s is **28.4%**.

**Verdict: directionally confirmed, but the stated threshold was narrowly missed, and
the mechanism is not the one predicted.**

- The saving is real — roughly **3.5× cheaper** than equivalent-depth first contact.
- But the mechanical comparison is essentially **free (6 seconds)**. It is not where
  the time goes. The residual 25 minutes is release-note reading, provenance
  corroboration, downloading, pre-mount verification, and *proving the instrument
  wasn't lying* — all judgment and corroboration work.
- This mirrors the QLMarkdown retrospective's central finding exactly: **the scriptable
  part is nearly free, and nearly all remaining cost is judgment.** Automating harder
  would not have helped; the 6-second step was already automated.

**A clean repeat should land near 10–12 minutes**, because calibration is now done, the
URL is known, and the CDHash proof is a known step. That is the same shape as the
Phase 5 prep measurement (24:08 first run → 5:18 clean re-run). The two distortions noted
above push the realistic figure lower still.

**Conclusion for the framework:** maintaining baselines on everything accepted is
worth it — band A is genuinely cheap and fits the 15-minute budget on a repeat run.
But "update audits are nearly free" is **too strong**. Budget ~10–15 minutes for a
routine update of a type-4 artifact, not 2.

---

## Friction encountered (input to the automation design)

1. **`mark.sh` could not be used.** It hardcodes `/Users/Shared/phase5-kit/` and offers
   only Phase-5 labels (`prep-start`, `exec-start`, …). Timings were taken by hand with
   `date`. Generalising the timing helper is now a concrete requirement, not a nicety.
2. **Command output exceeded the inline limit and had to be spilled to a file** — the
   same friction recorded in the QLMarkdown Phase 2 notes. Cap output per command.
3. **`codesign -dv` writes to stderr**, so a `sed`-based field extraction silently
   produced nothing on two bundle paths. The trap recorded in the QLMarkdown Phase 4
   notes bit again in a new place. A `shasum` comparison answered the question instead.
4. **`head` on a script's output produces exit 141 (SIGPIPE)**, which can be misread as
   a script failure. Not a defect, but a reporting trap.
5. **No update-audit report template existed.** This file is the first, and is the
   basis for [`../docs/05-update-audit.md`](../docs/05-update-audit.md).
6. **No documented path from `quarantine/` to production existed — the largest
   procedural gap the run exposed.** The framework was explicit that the gate is on
   execution and that nothing may be run from `quarantine/`, but said nothing about what
   happens *after* an Accept. Left unstated, the path of least resistance is the app's
   own "Check for Updates" button, which **re-downloads** and silently breaks the
   audited-bytes → installed-bytes chain — turning a completed audit into an Accept with
   no evidence. Now addressed by the quarantine → approved-staging transition in
   [`../docs/05-update-audit.md`](../docs/05-update-audit.md) Step 8.

7. **Truncating output for readability produced a false finding in this very report.**
   Piping a calibration result through `head -25` hid the detectors that fired further
   down, and the report was then written claiming a coverage gap that did not exist
   (corrected in Part 2). Filtering output is not neutral: it silently changes what the
   evidence appears to say. **Count or classify the full output before summarising it**
   — `grep -c`, `sort | uniq -c` — rather than reading the first screenful. Closely
   related to items 2 and 4, and to findings 8 and 9: in every case the tool worked and
   the *question asked of it* was wrong.
