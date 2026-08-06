# Intake Review — Little Snitch 6.4.1

> **Status: complete.** Audited at **P1 + P4** depth by reviewer decision; Phases 2, 3
> and 5 are recorded below as **explicitly out of scope with reasons**, not as gaps.
>
> **Result key:** ✅ pass · ⚠️ concern · 🛑 dealbreaker · ➖ N/A or out of scope.
> An unknown that can't be resolved is a ⚠️ or 🛑 — never a ✅.

---

## Summary

| Field | Value |
|-------|-------|
| **Software** | Little Snitch 6.4.1 (build 7212) — macOS outbound application firewall & network monitor |
| **Vendor / source** | Objective Development Software GmbH, Vienna, Austria — https://www.obdev.at/products/littlesnitch/ · **closed source, commercial** |
| **Exact version audited** | **6.4.1 (build 7212)**, released 2026-06-21. DMG SHA-256 `46074f19a492dbb36dbbbfc267942beff662b2f2f938c5e517d7e090ba0d7264` · app CDHash `642f3ccb609fffcfbd2a548fddd46e8b3c87df49` |
| **Artifact type** (from triage) | **Type 4 — system extension / OS add-on.** Ships **two** system extensions: a NetworkExtension content filter and an **Endpoint Security** client |
| **Install method** | Pre-built vendor-signed `.dmg`; drag-install app, **no `.pkg`**, no install scripts |
| **Date of audit** | 2026-08-05 |
| **Reviewer** | Repo maintainer (human). AI assistant gathered and explained evidence only. |
| **Overall risk rating** | **Medium** — highest-privilege artifact class, offset by unusually strong provenance and binary evidence |
| **DECISION** | 🟢 **ACCEPT** |
| **Decision made by** (a human — not the AI) | **Repo maintainer (human), 2026-08-05.** AI gathered and explained evidence only; the AI made no accept/reject determination. |
| **One-line rationale** | Authenticity, integrity and signing identity are cryptographically proven; the shipped binaries claim *narrower* privilege than Apple authorized; and the vendor is a 20-year, legally accountable entity with mature vulnerability-disclosure practice. |
| **Re-audit trigger** | **Any new version** (the app self-updates); any release claiming `packet-tunnel-provider` or `app-proxy-provider`; any change of Team ID from `MLZF7K7B5R`. Re-audit runs via [`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh) against the baseline recorded below. |

> **Purpose of intake:** adopted as **monitoring tooling** for the Phase 5 runtime review of
> QLMarkdown ([`qlmarkdown-v1.5.0-intake.md`](qlmarkdown-v1.5.0-intake.md)), as anticipated by
> [`../docs/checklists/phase-5-isolation-setup.md`](../docs/checklists/phase-5-isolation-setup.md).

---

## Step 0 — Triage ✅ complete

- **Artifact type & why:** **Type 4.** Compiled, invoked automatically by the OS, and installs
  two system extensions. Per [`../docs/02-artifact-triage.md`](../docs/02-artifact-triage.md)
  this is the highest-risk routine category. It is **more privileged than the QLMarkdown case**
  the framework was built around: a content filter observes every network flow on the machine,
  and an Endpoint Security client observes process-execution events system-wide.
- **Depth chosen & proportionality reasoning:** Reviewer chose **P1 + P4 in full**, deferring
  the depth decision until Phase 4 evidence was in hand. Rationale: Phases 2 and 3 are
  *structurally impossible* for a closed-source commercial binary, so running "all five phases"
  would mean recording N/A in three of them. Recording the exclusions honestly is more truthful
  than a nominally complete audit.
- **Phases out of scope, with reasons:**
  - **P2 supply chain — ➖ N/A.** No source, no manifest, no lockfile, no readable build
    scripts. *Partially substituted* by `otool -L` linkage review and component enumeration in
    P4, which found **zero non-Apple libraries**.
  - **P3 source review — ➖ N/A.** Closed source; nothing to read.
  - **P5 runtime — ➖ out of scope, two distinct reasons.** (a) *Network self-observation is
    circular by construction*: this artifact **is** the observation instrument, sits in the
    filter path, and cannot be used to validate its own network behaviour. (b) *Isolation is
    largely unavailable*: a system extension requires system-level installation plus a System
    Settings approval and cannot be meaningfully sandboxed. **Noted for the record:** all six of
    this product's historical CVEs lived in the installer / privileged-helper / persistence
    surface — the part P5 *would* examine, and which is **not** circular. That surface was
    therefore reviewed statically in P4 instead.
- **Source↔binary correspondence:** **Not establishable.** Closed source. Trust rests on
  cryptographic identity (P4) plus vendor accountability (P1), not on reading code.

---

## Phase 1 — Provenance & reputation ✅ complete

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Genuine vendor & official download path | ✅ | Reached by typing `obdev.at` directly, not via search results. `kMDItemWhereFroms` records file URL `https://obdev.at/ftp/pub/Products/littlesnitch/LittleSnitch-6.4.1.dmg` and referrer `https://obdev.at/products/littlesnitch/download.html`. Same registrable domain, HTTPS. *(The published link path `/downloads/littlesnitch/` redirects to `/ftp/pub/Products/` — noted and benign.)* |
| Vendor is a real, accountable entity | ✅ | Objective Development Software GmbH, Große Schiffgasse 1a/7, 1020 Vienna, Austria. **Registered at the Commercial Court Vienna, FN 244130 s.** Founded 2004; Little Snitch shipping 20+ years. Other products (LaunchBar, Micro Snitch, IAP Viewer) corroborate an ongoing business. |
| Maintenance recency / release history | ✅ | 6.4.1 released 2026-06-21, ~6 weeks before audit; current shipping build. Detailed public release notes back to 6.0. |
| Version currency & pinning | ✅ | **Pinned to 6.4.1 (7212).** Current release. *Compatibility note: vendor states 6.4.1 is not compatible with the macOS 27 "Golden Gate" beta.* |
| Security posture / disclosure practice | ✅ | **Six CVEs, all self-reported** (`sourceIdentifier: office@obdev.at`) with vendor-published advisory pages at `obdev.at/cve/`. A vendor that files CVEs against itself is showing mature practice, not a clean record by silence. |
| Known vulnerability history | ⚠️ *(informational)* | CVE-2016-8661 (kext buffer overflow → ring-0 EoP, CVSS 8.4) · CVE-2017-2675 (installer LPE via LaunchDaemon plist, 7.8) · CVE-2018-10470 (fat-binary code-signature validation flaw, 5.3) · CVE-2019-13013 & -13014 (privileged-helper XPC LPE + incomplete fix, 5.5) · CVE-2020-13095 (chown/symlink → root, 8.8). **All in 3.x/4.x. None in 5.x or 6.x.** Little Snitch 5 moved off the kernel extension onto Apple's NetworkExtension framework, structurally eliminating the ring-0 class. *Absence of CVEs since 2020 is not proof of absence of vulnerabilities.* |
| Privacy posture disclosed | ✅ | Published policy: update check transmits installed version, macOS version, CPU architecture, language, prerelease preference and licence validity. The old "Research Assistant" (which sent third-party program names to the vendor) was **removed in version 5** in favour of a built-in database. |
| Maintainer-trust proportionality | ⚠️ *(accepted)* | A content filter plus an Endpoint Security client is close to the maximum observational authority a non-Apple product can hold on macOS. *Correction to a common assumption: since v5 this is **not** kernel code — it is a userspace system extension, which lowers blast radius but does **not** lower the required trust, because data access is unchanged.* |
| External reputation search | ⚠️ *(gap)* | Trojanized/cracked Little Snitch builds on torrent and "crack" sites are a widely-cited malware lure — **a specific citation was not verified during this session.** Recorded as rationale for the official-download rule, **not** as confirmed evidence. |

---

## Phase 2 — Supply chain ➖ OUT OF SCOPE

**Reason:** closed-source commercial binary. No dependency manifest, lockfile, submodules or
readable build scripts exist to review.

**Partial substitute performed in Phase 4:** `otool -L` on the main app and both system
extensions found **zero non-Apple linked libraries** — no Sparkle, no analytics SDK, no crash
reporter, no bundled crypto. A filesystem sweep found **no bundled scripts** of any kind
(`.sh`, `.py`, `.rb`, `.pl`, `.command`, `.scpt`). The vendor ships a first-party updater rather
than a third-party framework. This is the strongest supply-chain signal obtainable without
source.

---

## Phase 3 — Source review ➖ OUT OF SCOPE

**Reason:** closed source. Nothing to read. No fork diff, no untrusted-input path analysis and
no telemetry code review is possible. This is a **known and accepted limitation** of adopting a
commercial binary, and it is why Phase 1 vendor accountability and Phase 4 cryptographic
identity carry the full weight of the decision.

---

## Phase 4 — Binary / artifact ✅ complete

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Official HTTPS source | ✅ | See Phase 1. Downloaded via browser (not `curl`) so the quarantine flag was set. |
| SHA-256 recorded | ➖ | `46074f19…0d7264`. **Vendor publishes no checksum** — recorded as a baseline, not a comparison. The vendor instead publishes a designated-requirement check, which is *stronger*: a hash served from the same page as the file only detects transit tampering, while a signature binds the file to an Apple-issued identity. |
| Quarantine flag present | ✅ | `com.apple.quarantine: 0083;6a73b268;Safari;…` — agent **Safari**; hex timestamp decodes to the file mtime exactly. No anomaly. |
| DMG signature valid & unmodified | ✅ | `codesign --verify --verbose=2` → *valid on disk*, *satisfies its Designated Requirement*, exit 0. |
| DMG signing identity | ✅ | `Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)` → `Developer ID Certification Authority` → `Apple Root CA`. **Secure Apple timestamp 2026-06-22 01:45:48**, matching the published 6.4.1 release date — two independent sources agreeing. |
| Vendor designated-requirement check | ✅ | `codesign --verify -R="anchor apple generic and certificate leaf[subject.OU] = MLZF7K7B5R"` → empty output, exit 0. Run independently by the reviewer and by the assistant. Team ID `MLZF7K7B5R` was obtained from the vendor's website **before** download — a genuine independent cross-check, not circular. |
| **DMG notarized / stapled** | ⚠️ | **The DMG wrapper is NOT notarized.** Confirmed four ways with network up and a working positive control: `spctl -a -t open` → *rejected, Unnotarized Developer ID*; `spctl -t install` → same; `stapler validate` → *does not have a ticket stapled*; `syspolicy_check distribution` → *"Notary Ticket Missing … Severity: Fatal"*. Control: a known-notarized third-party app passes the identical `codesign -R='notarized'` check (exit 0). |
| **App notarized / stapled / Gatekeeper** | ✅ | **Resolved — benign packaging.** `Notarization Ticket=stapled`; `stapler validate` → *The validate action worked!*; `spctl -a -vvv` → **accepted, source=Notarized Developer ID**; `codesign -R='notarized'` → *explicit requirement satisfied*. Both system extensions individually Gatekeeper-**accepted**. App signed 01:44:02, DMG 01:45:48 — a two-minute gap consistent with *sign → notarize → staple app, then build and sign the DMG around it.* |
| Entitlements minimal & sensible | ✅ | Privilege is **concentrated in the two system extensions and stripped from everything else**. Endpoint Security ext: `endpoint-security.client` only, **no network entitlements**. Network ext: `content-filter-provider` + `dns-proxy`, `app-sandbox = 0`. Agent: `personal-information.location` only. Network Monitor: `automation.apple-events` only. **Software Update, CLI, daemon, XPC service and codesignaturechecker: no entitlements at all.** |
| Dangerous entitlements absent | ✅ | Verified absent everywhere: `get-task-allow` (debuggable build), `disable-library-validation`, `allow-unsigned-executable-memory`, `allow-dyld-environment-variables`, any `com.apple.private.*`, microphone, camera, Address Book, Photos, Calendar. |
| **Declared privilege vs. Apple-authorized** | ✅ *(notable)* | Apple's embedded provisioning profiles grant this Team ID **five** NetworkExtension capabilities — including `packet-tunnel-provider` (VPN-level, could route all traffic) and `app-proxy-provider` — plus `keychain-access-groups`. **The shipped binaries claim only two** (`content-filter-provider`, `dns-proxy`) and claim **no keychain access at all**. Actual privilege is materially narrower than authorized privilege. The ES extension carries its own Apple-issued profile explicitly granting `endpoint-security.client`, an entitlement Apple gates behind manual review. |
| Hardened runtime & signing flags | ✅ | **All 10 Mach-O binaries** carry `flags=0x12b00(hard,kill,restrict,library-validation,runtime)` — Hardened Runtime **plus** library validation (refuses dylibs not signed by the same Team ID or Apple), `restrict` (blocks debugger attach / DYLD injection) and `kill`. Uniform across every component, including helpers. |
| Team ID uniformity | ✅ | Enumerating every Mach-O and grouping by Team ID yields a single line: **`10 TeamIdentifier=MLZF7K7B5R`**. No component signed by a foreign team. |
| Non-Apple linked libraries | ✅ | **Zero**, across main app, network extension and Endpoint Security extension. |
| Mach-O strings — network destinations | ✅ | All HTTPS, no IP literals, no third-party telemetry. `sw-update.obdev.at/software-update.php` (updates) · `blocklists.obdev.at/…/featured-blocklists.json` · `obdev.at/go/…` (help/purchase deep links) · DoH resolvers Cloudflare, Google, `dns10.quad9.net`, `unfiltered.joindns4.eu`. The last two **exactly match the 6.4 release notes** ("unfiltered Quad9 endpoints", "replaced with DNS4EU") — published documentation corroborated against the binary. **The Endpoint Security extension contains no URLs at all.** |
| Mach-O strings — suspicious patterns | ✅ *(with notes)* | No `.ssh/`, `id_rsa`, `base64 -d`, `curl -s` or `osascript` in any component. `/bin/sh` and `/bin/bash` appear in all binaries — **treated as noise**, since these strings are present in nearly every Swift/ObjC binary via runtime and Foundation internals. |
| Persistence mechanisms | ✅ *(disclosed & expected)* | `/Library/LaunchDaemons/at.obdev.littlesnitchd.plist`, `/Library/LaunchAgents/at.obdev.LittleSnitchHelper.plist`, `/Library/LaunchAgents/at.obdev.LittleSnitchUIAgent.plist`. Functionally necessary — a firewall that did not persist could not filter at boot — and in standard, inspectable locations rather than hidden ones. *`at.obdev.littlesnitchd.plist` is the exact file involved in CVE-2017-2675.* |
| `.pkg` / installer scripts inspected | ➖ | **No `.pkg` exists.** The DMG contains a drag-install app that installs its own extensions at runtime behind a System Settings approval. **There are therefore no pre/postinstall scripts** — the classic elevated-script vector is absent by design. |
| Image handled without executing | ✅ | Mounted `hdiutil attach -readonly -nobrowse -noautoopen`; all internal CRC32s verified on attach; mount flags `read-only, nodev, nosuid, noowners, quarantine, nobrowse`; detached cleanly. Nothing was installed, launched or executed at any point. |

---

## Phase 5 — Runtime / sandbox ➖ OUT OF SCOPE

See Step 0 for the full reasoning. In summary:

- **Network self-observation: N/A by construction.** The artifact is the observation instrument.
  It sits in the filter path and cannot validate its own network behaviour — a compromised
  filter could simply decline to report its own traffic.
- **Isolation largely unavailable.** A system extension cannot be meaningfully sandboxed; it
  requires system-level install plus explicit user approval. The vendor's own release notes
  record VM-specific defects (licence-key crash in a VM; daemon crash in a VM on macOS 26.1),
  so VM testing is possible but imperfect.
- **Non-circular observation would require an out-of-band vantage point** (upstream router or
  host-level capture). Judged disproportionate for this intake; recorded as available if the
  residual question ever needs closing.

---

## Findings & open questions

1. **The DMG wrapper is not notarized; the app inside is.** Resolved as benign packaging, but a
   real deviation from Apple's recommended distribution practice — `syspolicy_check` grades it
   *"Severity: Fatal / Distribution Error."* Practical consequences: Apple's automated scan
   covered the app rather than the container, and **offline verification of the container is
   impossible**.
2. **The vendor's published verification instructions point users only at the `codesign -R`
   check — the one that passes.** That check is sound and proves authenticity, but a user
   following the vendor's guidance to the letter would never discover the DMG is unnotarized.
   *This framework's Phase 4 surfaced something the vendor's own instructions do not.*
3. **The Software Update component is the ongoing trust dependency.** It references `NSTask`,
   fetches from `sw-update.obdev.at`, and by design installs new code. It carries **zero
   entitlements** and is hardened, which limits it — but **the artifact audited here can replace
   itself with one that was never reviewed.** Addressed by the Operating notes and the re-audit
   trigger below.
4. **Apple's authorization ceiling exceeds current use.** `packet-tunnel-provider` and
   `app-proxy-provider` are granted but unclaimed. A future build could claim them **without
   requiring new Apple approval** — hence the specific re-audit trigger.
5. **The Agent requests Location.** Explained by Wi-Fi SSID access for Automatic Profile
   Switching (macOS gates SSID behind Location Services) and corroborated by `CoreLocation`
   linkage. Declinable at the prompt if Automatic Profile Switching is not used.
6. **Diagnostic reports enumerate launch items.** Strings `ls_system_LaunchAgents.txt`,
   `ls_system_LaunchDaemons_permissions.txt` indicate the troubleshooting bundle lists
   LaunchAgents/LaunchDaemons and their permissions. User-initiated, but worth knowing before
   sending a diagnostic bundle from a machine holding sensitive material.
7. **`strings` absence is weak negative evidence.** It sees only literal, unobfuscated ASCII.
   Demonstrated concretely: the geolocation-database update URL described in the release notes
   **did not appear** in any binary, yet the feature exists.
8. **Unverified external-reputation item** — see Phase 1, recorded as a gap rather than quietly
   dropped.

## Dealbreakers encountered

- **None.**

## Conditions / restrictions if installing

- **None imposed.** The reviewer recorded a clean **Accept**: the artifact is accepted
  unconditionally, and acceptance is not contingent on any limit being observed.

> **Why the update policy below is *not* filed as a restriction.** In this framework a
> *restriction* means *"I am accepting a risk only because I have bounded it."* The update
> handling recorded under **Operating notes** is a standing operational preference that would
> apply to any high-blast-radius tool — it is not bounding an unexplained risk in this artifact.
> Filing it as a restriction would misstate why it exists and imply the acceptance is
> conditional when it is not.

## Operating notes (how this is run, not a condition of acceptance)

- **Automatic update *check*: ON.** Cheap, and it delivers the signal — you learn about a
  security release within a day.
- **Automatic update *install*: OFF.** Preserves deliberate soak time. Rationale is
  evidence-based rather than generic caution: across the 6.x line the vendor shipped six
  regressions serious enough to need hotfixes — rules wiped on upgrade (6.0.4), DNS left
  unencrypted despite encryption being enabled (6.1.1), **the auto-updater itself breaking**
  (6.2.2), network-filter crash causing loss of connectivity (6.3.1), a crash disconnecting all
  active connections (6.3.2) and valid licences rejected (6.4.1). **For this product the
  empirically dominant failure mode is vendor regression, not attacker compromise.** On that
  history a 4–6 week soak would have avoided most of them; note honestly that 6.3 → 6.3.1 took
  six months, so no soak period catches everything.
- **Frozen for the duration of the QLMarkdown Phase 5 review.** Methodological, not security:
  changing the measuring instrument mid-experiment invalidates the measurement.
- **On each new version, run the tiered check** rather than a full re-audit:
  - *Tier 0* — read the release notes. Does this touch privilege or the trust anchor?
  - *Tier 1* — run [`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh)
    against the recorded baseline. Seconds, and it is the check that actually matters.
  - *Tier 2* — full re-audit only if Tier 1 reports drift, or on a major version bump.
- **Update-policy reasoning is per-artifact, on two axes** — *blast radius if the update is bad
  or malicious* and *exposure if you stay behind*. Little Snitch is high-blast-radius but
  **low-exposure-if-behind** (not an inbound service; no CVEs in 5.x/6.x; the entire historical
  CVE class is local privilege escalation requiring prior code execution). Software in the
  opposite quadrant — browsers, OS security updates, anything internet-facing — warrants the
  opposite policy: auto-update immediately.

## Decision rationale

Phase 4 settled the questions it is capable of settling, and settled them cleanly: the bytes are
provably those Objective Development signed on 2026-06-22; the signing identity chains to Apple
Root CA and matches a Team ID obtained independently before download; every one of ten
components shares that Team ID and a uniformly hardened signing configuration; no third-party
library or script is bundled; and the shipped binaries request *less* privilege than Apple
authorized. Phase 1 establishes a legally accountable, two-decade vendor that files CVEs against
itself and publishes advisories.

What remains is not a question of authenticity — that is proven — but of **whether to grant this
vendor network-filter and Endpoint Security authority on an artifact that can update itself.**
The reviewer judged the evidence sufficient and accepted that trade-off knowingly.

**What this decision explicitly does not rest on:** signing and notarization prove the code is
*unmodified and from an identified party that passed an automated malware scan* — they do **not**
prove the software is safe, honest or free of vulnerabilities. No source was read and no runtime
behaviour was observed. All findings are point-in-time.

## Fitness-for-purpose note (monitoring QLMarkdown)

Adopted to observe a **Quick Look extension**, where connections are frequently attributed to
Apple host processes rather than the extension under test. Recorded so the QLMarkdown Phase 5
does not over-claim:

- Little Snitch has actively improved extension attribution — the 6.2.1 and 6.3 release notes
  cite attributing XPC-helper and app-extension traffic to the owning extension.
- **But WebKit is the material gap:** QLMarkdown renders HTML, and if it uses `WKWebView`,
  remote resource loads (remote images, Mermaid from a CDN) egress via
  `com.apple.WebKit.Networking` — an Apple process — **not** the extension. DNS resolves via
  `mDNSResponder`, background URLSession via `nsurlsessiond`, revocation checks via `trustd`.
- **Precedent that Apple can narrow this visibility:** macOS 11.0 shipped a
  `ContentFilterExclusionList` exempting Apple processes from third-party filters; removed in
  11.2 after criticism. Little Snitch's visibility is *granted by Apple's framework*.
- **CVE-2018-10470 is directly relevant:** it was a flaw in Little Snitch's code-signature
  validation *of the processes it monitors*. Fixed long ago, but it establishes that "Little
  Snitch says process X made this connection" is an assertion produced by code that has been
  wrong before.
- **Recommended for the QLMarkdown run:** Alert Mode on a clean profile with an empty rule set;
  disable the update check, blocklist auto-update and geolocation DB update so the instrument
  does not pollute its own measurement; leave DNS encryption off; correlate by timing and
  destination rather than process name alone; add an out-of-band capture; and also test with
  network **denied**.
- **Standing caveat:** observing no connections during a session proves nothing about code paths
  that were not triggered. Little Snitch makes Phase 5 evidence better; it does not make it
  proof.

---

## Appendix A — recorded baseline

The machine-checkable invariants below are what
[`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh) compares a future
version against. Regenerate with `--record` after mounting a new release read-only.

| Invariant | Value at 6.4.1 |
|-----------|----------------|
| Team ID (all components) | `MLZF7K7B5R` |
| Signing authority (leaf) | `Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)` |
| Mach-O component count | 10 |
| CodeDirectory flags (all) | `0x12b00` (hard, kill, restrict, library-validation, runtime) |
| App notarization | stapled; Gatekeeper `accepted` |
| Non-Apple linked libraries | none |
| NetworkExtension entitlements claimed | `content-filter-provider-systemextension`, `dns-proxy-systemextension` |
| Endpoint Security entitlement | `com.apple.developer.endpoint-security.client` (ES extension only) |
| Sandbox | `app-sandbox = 0` on the network extension only |

## Appendix B — commands run (all read-only)

```
# Pre-mount, on the .dmg
shasum -a 256 <dmg>; xattr -l <dmg>; mdls -name kMDItemWhereFroms <dmg>
codesign --verify --verbose=2 <dmg>
codesign -dv --verbose=4 <dmg>
codesign --verify -R="anchor apple generic and certificate leaf[subject.OU] = MLZF7K7B5R" <dmg>
spctl -a -vvv -t open --context context:primary-signature <dmg>
spctl -a -vvv -t install <dmg>
xcrun stapler validate <dmg>
syspolicy_check distribution <dmg>
codesign --verify -vv -R='notarized' --check-notarization <dmg>   # + control vs. a known-notarized app
hdiutil imageinfo <dmg>

# Mount read-only (gate: only after the above pass)
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint <mnt> <dmg>

# On the app and every nested component
codesign --verify --deep --strict --verbose=2 <app>
codesign -dv --verbose=4 <each of 10 components>
xcrun stapler validate <app>; spctl -a -vvv <app>
codesign -d --entitlements - --xml <each of 10 components>
security cms -D -i <each embedded.provisionprofile>
otool -L <main app, network ext, endpoint security ext>
strings -a <binaries> | grep -oE 'https?://…'
find <app> -name '*.sh' -o -name '*.py' -o -name '*.scpt' …

hdiutil detach <mnt>
```

## Update log (re-audits of later versions)

| Date | New version | What changed (diff summary) | Re-verdict |
|------|-------------|-----------------------------|-----------|
| | | | |
