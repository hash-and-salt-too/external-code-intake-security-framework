# Intake Review — Micro Snitch 1.6.1

> **Status: Phase 4 complete; acceptance is contingent.** Audited at **P1 + P4** depth by
> reviewer decision. Phases 2 and 5 are recorded below as **explicitly out of scope or
> pending, with reasons** — not as silent gaps. Phase 3 was *partially* possible and was done.
>
> **Result key:** ✅ pass · ⚠️ concern · 🛑 dealbreaker · ➖ N/A or out of scope.
> An unknown that can't be resolved is a ⚠️ or 🛑 — never a ✅.

---

## Summary

| Field | Value |
|-------|-------|
| **Software** | Micro Snitch 1.6.1 (build 1337) — macOS microphone & camera *activity* monitor |
| **Vendor / source** | Objective Development Software GmbH, Vienna, Austria — https://www.obdev.at/products/microsnitch/ · **closed source, commercial** |
| **Exact version audited** | **1.6.1 (build 1337)**, released 2023-09-13. DMG SHA-256 `700a265156ae7c8138d7764a0ce87feba098bcaf77deed9b8d9aaa0b3c4fa197` · DMG CDHash `8853a47a8a8a70cd6c5340e15889638a58a679ae` |
| **Artifact type** (from triage) | **Type 3 — pre-built native app.** Two Mach-O binaries: the app and one in-bundle login item. **No system extension, no daemon, no kernel code** |
| **Install method** | Pre-built vendor-signed `.dmg`; drag-install app, **no `.pkg`**, no install scripts |
| **Date of audit** | 2026-08-06 |
| **Reviewer** | Repo maintainer (human). AI assistant gathered and explained evidence only. |
| **Overall risk rating** | **Low–Medium** — modest artifact class and minimal privilege, weighed against a privacy-sensitive function and a self-update capability |
| **DECISION** | 🟡 **ACCEPT WITH RESTRICTIONS** — *contingent on the first-launch verification below* |
| **Decision made by** (a human — not the AI) | **Repo maintainer (human), 2026-08-06.** The reviewer first recorded a Hold, then revised to Accept-with-restrictions after two factual corrections to the stated rationale. The AI gathered and explained evidence and made no accept/reject determination. |
| **One-line rationale** | Authenticity and signing identity are cryptographically proven, the app is structurally incapable of capturing audio or video, and it declares and appears to use exactly one network endpoint — but it can update itself and it logs device activity, so acceptance is bounded by two verifiable first-launch settings. |
| **Re-audit trigger** | **Any new version** (the app self-updates); any change of Team ID from `MLZF7K7B5R`; any release that adds a capture framework, a LaunchDaemon/LaunchAgent, a system extension, or a second network endpoint. Re-check runs via [`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh) against the baseline in Appendix A. |

---

## Step 0 — Triage ✅ complete

- **Artifact type & why: Type 3.** Determined from bundle contents, not vendor description.
  Exactly **two Mach-O binaries** — `Contents/MacOS/Micro Snitch` and an in-bundle login item
  at `Contents/Library/LoginItems/`. No system/network/kernel extension, no XPC service, no
  `SMJobBless` privileged helper, no LaunchDaemon or LaunchAgent. Drag-install DMG with an
  `Applications` symlink, so **no `.pkg` and no pre/postinstall scripts**.
- **Depth chosen & proportionality reasoning.** The reviewer was offered an explicit choice
  between **type-driven** depth (Type 3 → lighter) and **function-driven** depth, and chose
  function-driven. The type argues for less: no automatic OS invocation, no hostile-input
  parsing path, smaller surface than the QLMarkdown case this framework was built around. The
  function argues for more, decisively on one point: **this product is a detector, and a
  detector that lies is worse than no detector**, because it manufactures false assurance and
  you stop looking. That asymmetry is not captured by the type table.
- **Phases out of scope or pending, with reasons:**
  - **P2 supply chain — ➖ N/A.** Closed source; no manifest, lockfile, submodules or build
    scripts. *Partially substituted in P4:* `otool -L` found **zero third-party libraries**,
    and a content-type sweep found exactly **one** bundled script, which was read in full.
  - **P3 source review — ⚠️ partially possible, and performed.** The compiled code cannot be
    read, but the bundle ships one readable script (`Resources/listdevices`, Perl). It was
    reviewed line by line — see Phase 3.
  - **P5 runtime — ⏳ PENDING, and required.** Not out of scope: the two restrictions below can
    only be confirmed by launching the app. Until that is done the acceptance is contingent.
- **Source↔binary correspondence:** **Not establishable.** Closed source. Trust rests on
  cryptographic identity (P4) and vendor accountability (P1), not on reading code.

---

## Phase 1 — Provenance & reputation ✅ complete

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Genuine vendor & official download path | ✅ | `kMDItemWhereFroms` records file URL `https://obdev.at/ftp/pub/Products/MicroSnitch/MicroSnitch-1.6.1.dmg` and referrer `https://obdev.at/products/microsnitch/download.html`. Verified independently that the published download link `302`-redirects to that exact path. HTTPS throughout. |
| Vendor is a real, accountable entity | ✅ | Objective Development Software GmbH, Große Schiffgasse 1a/7, 1020 Vienna, Austria. **Registered at the Commercial Court Vienna, FN 244130 s.** Founded 2004. Corroborated independently by Apple's App Store record: `sellerName: "Objective Development Software GmbH"`, first release 2015-06-03 — matching the vendor's own 1.0 release note. |
| **Version currency** | ⚠️ | **1.6.1 is current, and is ~2 years 11 months old** (released 2023-09-13). Four independent sources agree: vendor release notes, vendor download page, Apple App Store `currentVersionReleaseDate: 2023-09-12`, and the **secure signing timestamp inside the artifact** (2023-09-13 14:01:27), which cannot be backdated. |
| Maintained vs. abandoned | ⚠️ *(finished, not abandoned)* | For: the download page claims compatibility with macOS Tahoe and Sequoia — **both released after this binary was built** — so someone still tests and republishes. Vendor actively ships other products. Against: multi-year gaps are this product's normal rhythm (1.3.1 in 2018 → 1.4 in 2021), so silence carries little signal; **no published security-maintenance policy.** *Practical risk:* a macOS change that broke detection would likely be fixed, but perhaps slowly — and **silent detection failure is this product's worst failure mode**, because "no activity" reads as "nothing happened." |
| **CVEs — this product specifically** | ✅ | **NVD keyword `micro snitch` → 0 results; `microsnitch` → 0 results.** OSV → no matches (expected: OSV indexes package ecosystems, not commercial macOS apps — **a null result there is near-meaningless and is not counted as reassurance**). |
| Vendor-level security history | ➖ *(informational)* | NVD `objective development` → 2 hits, both for **Sharity**, a discontinued CIFS client: CVE-2007-2178, CVE-2008-4057. Unrelated product, ~18 years old. Weak positive signal only, that the vendor historically shipped fixes. **Deliberately not inherited from any other obdev product.** |
| External reputation search | ✅ | No results for `"Micro Snitch"` + malware / trojan / vulnerability / security issue. |
| **Vendor's expected signing identity obtained before inspection** | ✅ | Team ID **`MLZF7K7B5R`**, taken from the vendor's own documentation at `help.obdev.at/littlesnitch6/adv-code-identity` **before the downloaded file was examined**, making the Phase 4 comparison a genuine cross-check rather than circular. *Honest limitation:* a Team ID is a **company-level** Apple identifier, and the page stating it documents a different product. The vendor publishes **no Micro Snitch-specific expected Team ID.** |
| **Checksum vs. signature published** | ⚠️ | **Vendor publishes neither a checksum nor a detached signature** — they rely wholly on Apple code signing + notarization. *Why that is defensible:* a checksum served from the same page as the file only detects transit or mirror tampering, because whoever controls the page controls both values. A **signature is stronger**: it binds the file to a private key that Apple has tied to a verified legal entity, and it survives a compromised website. |
| Privacy posture disclosed | ✅ | Privacy policy §1.5.1 enumerates exactly what the update check transmits: installed version, prerelease preference, macOS version, CPU architecture, language, licence validity, and manual-vs-automatic. **No device-activity data.** Vendor also ships a machine-readable Internet Access Policy in the bundle. |
| Maintainer-trust proportionality | ✅ | Privilege actually held is modest for a privacy tool: no kernel code, no system extension, no daemon, no admin persistence. The trust required is therefore lower than the product's *subject matter* first suggests. The residual trust demand is the **self-update capability**, addressed below. |
| **Version pinned** | ✅ | Pinned to **1.6.1 (1337)**; hash and baseline recorded. |

---

## Phase 2 — Supply chain ➖ OUT OF SCOPE

**Reason:** closed-source commercial binary. No dependency manifest, lockfile, submodules or
readable build scripts exist.

**Partial substitute performed in Phase 4:** `otool -L` on both binaries found **zero
third-party libraries** — no Sparkle, no analytics SDK, no crash reporter, no bundled crypto.
The vendor ships a **first-party updater** (`ODSU`) rather than a third-party framework, and
that updater verifies what it installs against obdev's own Team ID (see Phase 4). A
content-type sweep of every file found exactly **one** script. There is no `Contents/Frameworks`
directory, so nothing is bundled at all.

---

## Phase 3 — Source review ⚠️ PARTIAL (one readable component)

The compiled application cannot be read. **One component could be, and was reviewed in full.**

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| `Resources/listdevices` (Perl, 4,450 bytes) reviewed line by line | ✅ | A read-only log parser. Opens the activity log with `open(my $fh, '<', $fileName)`, matches device-state lines, prints a summary. |
| Network access | ✅ | **None.** No sockets, no HTTP, no `LWP`, no `curl`. |
| Command / process execution | ✅ | **None.** No `system()`, no backticks, no `exec`, no `open` pipes. |
| Dynamic / remote code execution | ✅ | **No `eval`.** |
| File writes or deletion | ✅ | **None.** Read-only; no `unlink`, no write handles. |
| Quality note *(not a security finding)* | ➖ | `my $fileName = $ARGV[0];` is re-declared inside the `if` block, shadowing the outer variable — so passing a log filename as an argument silently has no effect. A harmless bug. |

> **How this script became useful evidence.** Its parser documents the activity-log grammar:
> `Micro Snitch launched`, `Device found:`, `Device connected:`, `Device disconnected:`,
> `Device became active` / `Device became inactive`, over states `unsupported`, `disconnected`,
> `connected + inactive`, `connected + active`. Every token is a **device state transition**.
> Nothing in the format can express audio samples, video frames, recording duration or content
> — which independently corroborates the detect-not-capture finding in Phase 4.

---

## Phase 4 — Binary / artifact ✅ complete

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Official HTTPS source | ✅ | See Phase 1. Downloaded via **Safari**, so the quarantine flag was set. |
| Quarantine flag present & unstripped | ✅ | `com.apple.quarantine: 0083;6a73b857;Safari;…` — agent **Safari**. Still intact after the audit. |
| SHA-256 recorded | ➖ | `700a265156ae7c8138d7764a0ce87feba098bcaf77deed9b8d9aaa0b3c4fa197`. **Vendor publishes no checksum**, so this is a recorded baseline, not a comparison. |
| **Independent integrity comparison** | ✅ | Compensating check for the missing published hash: the file was **re-fetched from the vendor** and compared — hashes equal, `cmp` → **IDENTICAL**. *Proves your copy matches what obdev serves today; does **not** prove the release itself is honest.* |
| DMG signature valid & unmodified | ✅ | `codesign --verify --deep --strict --verbose=2` → *valid on disk*, *satisfies its Designated Requirement*. |
| DMG signing identity | ✅ | `Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)` → `Developer ID Certification Authority` → `Apple Root CA`. |
| **Team ID vs. independently-obtained value** | ✅ | `TeamIdentifier=MLZF7K7B5R` — **matches the value taken from the vendor's site before the file was inspected.** |
| Secure timestamp vs. published release date | ✅ | App signed **2023-09-13 14:01:27**, helper 14:01:23, DMG 14:02:11. Vendor release notes and Apple both date 1.6.1 to 2023-09-12/13. Independent agreement; a secure timestamp cannot be backdated. |
| **DMG notarized / stapled** | ⚠️ | **The DMG wrapper is NOT notarized.** Three tools agree, with validated controls: `spctl -a -t open` → *rejected, Unnotarized Developer ID*; `stapler validate` → *does not have a ticket stapled*; `syspolicy_check distribution` → *Notary Ticket Missing, Severity: Fatal*. |
| **App notarized / stapled / Gatekeeper** | ✅ | **Resolved — benign packaging.** `spctl -a -vvv` → **accepted, source=Notarized Developer ID**; `stapler validate` → *The validate action worked!*; stapled ticket present at `Contents/CodeResources`. The vendor stapled the app, not the container. |
| App signature incl. nested component | ✅ | `--deep --strict` → *valid on disk*, *satisfies its Designated Requirement*; the login helper was explicitly prepared and validated. |
| **Team ID uniformity across every Mach-O** | ✅ | All four targets — both bundles and both Mach-O binaries — report `TeamIdentifier=MLZF7K7B5R` with the identical authority chain. **No component signed by a different team.** |
| **CodeDirectory flags / hardened runtime** | ⚠️ | `flags=0x10000 (runtime)` on **both** binaries: **hardened runtime enabled**. The standalone `library-validation` flag (`0x2000`) is **not** set, but the hardened runtime enforces library validation by default and **no `com.apple.security.cs.disable-library-validation` entitlement is present**, so it is in effect. **`kill`, `restrict` and `hard` are not set** — a modestly weaker posture than some signed apps, and it matters slightly more because the main app is not sandboxed. |
| Dylib-planting surface | ✅ *(mitigated)* | The binary carries an `@executable_path/../Frameworks` rpath while **no `Contents/Frameworks` directory exists** — a classic planting target, neutralised by library validation (any planted dylib would need obdev's or Apple's signature). |
| **Entitlements — main app** | ⚠️ | Exactly two: `com.apple.security.device.audio-input`, `com.apple.security.device.camera`. **`com.apple.security.app-sandbox` is absent, so the main app is NOT sandboxed** — and because both are *App Sandbox* entitlements, they are **inert**: they neither grant nor restrict anything here. Most likely a shared entitlements file with the sandboxed Mac App Store build. **The substantive fact is that the app runs with full user privileges.** |
| Entitlements — login helper | ✅ | `com.apple.security.app-sandbox = 1` only. Sandboxed. |
| Dangerous entitlements absent | ✅ | Verified absent on all components: `get-task-allow`, `disable-library-validation`, `allow-unsigned-executable-memory`, `allow-dyld-environment-variables`, any `com.apple.private.*`. |
| **Embedded provisioning profile** | ➖ | **None present anywhere in the bundle**, so `security cms -D -i` is **N/A** and the granted-vs-claimed comparison **cannot be performed**. Recorded as an explicit N/A, not a pass. Developer ID apps only carry a profile when using entitlements Apple must individually authorise; these are not such entitlements. **Net effect: Apple granted nothing beyond Developer ID signing; the binaries claim two entitlements; and with the sandbox off, those claims have no effect.** |
| **CAPTURE vs DETECT** | ✅ | **Structurally incapable of capture.** Four independent grounds — see the dedicated section below. |
| Non-Apple linked libraries | ✅ | **Zero.** All dependencies are OS frameworks or `/usr/lib`. The 15 `@rpath/libswift*.dylib` entries are **Apple's Swift runtime**, resolving via the `/usr/lib/swift` rpath because no `Contents/Frameworks` exists. |
| Bundled scripts | ✅ *(one, reviewed)* | A content-type sweep — not an extension match — found exactly one: `Resources/listdevices` (Perl, no file extension). Reviewed in full in Phase 3. |
| **Privileged execution capability** | ⚠️ | **Real and reported, not written off.** See the dedicated section below. |
| Persistence mechanisms | ✅ *(minimal)* | A single in-bundle login item (`ServiceManagement`). **No LaunchAgent, LaunchDaemon, `launchctl` or `SMJobBless` reference found.** Nothing runs when the app is not running. |
| Sensitive-path access | ✅ *(weak evidence)* | No `.ssh`, `id_rsa`, keychain, `.aws`, `.netrc`, cookie or browser-history strings. **Weak negative evidence in a Swift binary** — see the `strings` caveat below. |
| `.pkg` / installer scripts inspected | ➖ | **No `.pkg` exists.** Drag-install app plus an `Applications` symlink, so the elevated-install-script vector is **absent by design**. |
| Image handled without executing | ✅ | Mounted `hdiutil attach -readonly -nobrowse -noautoopen`; internal CRC32 verified (`hdiutil verify` → VALID); detached cleanly; file hash and quarantine flag **unchanged afterwards**. Nothing was installed, launched or executed at any point. |

### Capture vs. detect — the finding this product turns on

**It cannot capture audio or video.** Not "does not" — *cannot*, on four independent grounds:

1. **Imported symbols (`nm -u`) — the strongest evidence.** Every media API imported is a
   property/metadata call: `AudioObjectGetPropertyData`, `AudioObjectHasProperty`,
   `AudioObjectAdd/RemovePropertyListenerBlock`, `AudioObjectSetPropertyData`, and the
   `CMIOObject*` equivalents, plus `CGDisplayIsCaptured`. **None can move an audio sample or a
   video frame.** Capture would require `AVCaptureSession`, `AVAudioRecorder`,
   `AudioQueueNewInput`, `AudioUnitRender`, `ExtAudioFile*` or `CMSampleBuffer` handling —
   **zero of these are imported.**
2. **`AVFoundation` is not linked at all.** Only `CoreAudio` and `CoreMediaIO` — the device
   layer.
3. **No `NSMicrophoneUsageDescription` / `NSCameraUsageDescription` in `Info.plist`.** This is
   **not** an "absence = reassurance" argument: since macOS 10.14 (this app targets 10.14.6),
   TCC **terminates** any process calling the mic/camera capture APIs without the matching
   purpose string. It is an **OS-enforced blocker** — if it tried, macOS would kill it.
4. **The activity-log grammar** recovered from the bundled Perl script contains only device
   state transitions (Phase 3).

**Residual nuance, stated rather than smoothed over:** `AudioObjectSetPropertyData` and
`CMIOObjectSetPropertyData` can **write** device properties, so the app is not purely passive.
Benign uses exist. Neither can capture content.

**Where the activity log goes, and who can read it.** For this non-sandboxed build:
`~/Library/Logs/Micro Snitch.log`, plus the unified Console log. Confirmed by the Perl script's
hardcoded paths and by `logFileURL` / `Logs/` / `revealLogFile:` strings.
**`~/Library/Logs` is not TCC-protected, so any process running as your user can read your
microphone and camera activity timeline with no permission prompt.** That is a genuine local
privacy exposure — about other software on the machine, **not** about vendor exfiltration.
Primary-source note: release note 1.3 records *"Fixed a crash when disabling the activity
log,"* which establishes that **the activity log can be turned off**.

### Network behaviour — declared, and cross-checked

The vendor ships a machine-readable **Internet Access Policy** inside the code-signed bundle
(therefore tamper-evident), declaring **exactly one connection**:

```
Host: sw-update.obdev.at   Port: 443   NetworkProtocol: TCP
Purpose: SoftwareUpdateCheckPurpose
```

| Cross-check | Result |
|---|---|
| Network APIs imported | **`NSURLSession` / `NSURLSessionConfiguration` only.** No raw sockets, no `CFSocket`, no `NWConnection`, no custom TLS |
| Domains present in the binary | **`obdev.at` only** (help/support/FAQ deep links). No third-party domain, no analytics or telemetry host |
| Endpoints in the binary that the policy omits | **None found** — the direction that would matter |
| Declared host confirmed in the binary | ❌ **No.** `sw-update` appears **only** in the policy file; **0 matches in the x86_64 slice and 0 in the arm64 slice.** Evidently assembled at runtime. Recorded as a limitation of the method, not as a contradiction |

### Privileged execution — reported, not dismissed

`/bin/sh`, `NSTask` and `system.privilege.admin` are present. Surrounding strings identify the
region conclusively as **`ODSU` — Objective Development Software Update**:

```
/bin/rm -rf "$ODSU_OLD_APP_TEMP_PATH" 2>&1
/bin/mv  "$ODSU_OLD_APP_TEMP_PATH" /tmp/ 2>&1
setenv %@=%@
system.privilege.admin
/bin/sh
root shell: %@
( %@ ); echo "/$?"
```

with selectors `setLaunchPath:`, `setArguments:`, `waitUntilExit`, and
`_authorizationReference`, `shellWithAuthorizationReferenceFromShell:`.

**So the app can obtain admin authorization and run shell commands as root.** What bounds it:

- The commands are narrow and fixed (`rm -rf`, `mv` on the old app copy during self-update) —
  the standard way an app replaces itself in `/Applications`.
- The path is passed via an **environment variable**, not interpolated into the shell string —
  a deliberate choice that makes the command immune to shell injection via a crafted filename.
- **The updater cryptographically verifies what it installs.** Embedded requirement:
  `anchor apple generic and certificate leaf[subject.OU] = "MLZF7K7B5R" and certificate
  leaf[field.1.2.840.113635.100.6.1.13] exists`, with strings
  *"Signature check: Downloaded file has invalid code signature, rejecting"* /
  *"Accepted because it meets code signature requirement."* A pinned **DSA-2048** public key
  ships at `Resources/ODSoftwareUpdatePublicKey.pem`. **A hijacked update server or DNS alone
  cannot push code here** — obdev's signing key would also be required.
- The deprecated `AuthorizationExecuteWithPrivileges` is **not** used, and **no privileged
  helper daemon is installed**.

**What is not bounded:** `strings` proves the capability exists; it cannot prove when, whether,
or under what conditions it runs. **By design, the artifact audited here can replace itself
with one nobody audited.** This is the basis of Restriction 1.

### What `strings` cannot prove — demonstrated in this session

Two concrete failures, recorded so the negative results above are read with the right discount:

- It reported an **IP address, `100.6.1.13`**. No such address exists — it was a fragment of the
  OID `1.2.840.113635.100.6.1.13` (Apple's Developer ID certificate extension) inside a codesign
  requirement string. The regex matched a pattern that meant something else entirely.
- It **failed to find `sw-update.obdev.at`**, a host the vendor explicitly declares. The feature
  exists; the literal does not.

`strings` finding something is weak evidence *for*; `strings` finding nothing is weak evidence
*against*. It sees literal ASCII runs, and this is a Swift binary where much is mangled or
constructed at runtime.

---

## Phase 5 — Runtime / sandbox ⏳ PENDING (required by the restrictions)

**Not out of scope.** Both restrictions are first-launch settings that can only be confirmed by
running the app. Until that is done, **the acceptance is contingent.**

**Recommended isolation — a separate local user account on real hardware, network off for the
first launch.** Reasoning:

- **A VM is actively the wrong tool here.** This app's function depends on enumerating real
  CoreAudio/CoreMediaIO hardware; a VM lacks a genuine built-in camera and microphone, so it may
  report no devices or "unsupported" ones — poor fidelity for the exact thing being verified.
- **A separate user account fits the artifact.** With no daemon, no LaunchAgent and no system
  extension, everything this app touches is **per-user state** — its login item and its log in
  `~/Library/Logs/`. A second account isolates precisely those, while preserving real hardware.

Procedure:

1. Create a throwaway local user account.
2. Copy `Micro Snitch.app` into **that account's own folder, not `/Applications`.** The
   updater's admin-escalation path exists to replace the app where the user cannot write; from a
   user-writable location it should be unnecessary — **and an admin prompt anyway is itself a
   finding.**
3. **Disable Wi-Fi/Ethernet, then launch.** Guarantees no update check can occur before the
   settings are reachable.
4. Verify and set: automatic update check **off**; activity log **off**.
5. Quit. Check whether `~/Library/Logs/Micro Snitch.log` was created and whether a login item
   was registered.
6. Re-enable the network only afterwards.

**Expected-result note:** device-state observation requires no TCC permission, so **no
microphone or camera prompt should appear.** If one does, it contradicts the Phase 4 capture
finding — stop and re-open the audit.

---

## Findings & open questions

1. **The DMG wrapper is not notarized; the app inside is.** Benign packaging, but a real
   deviation from Apple's recommended practice, and it means **offline verification of the
   container is impossible.** Anyone verifying only the DMG would get an alarming result.
2. **The main app is not sandboxed**, and its two mic/camera entitlements are **App Sandbox
   entitlements rendered inert** by the sandbox being off. The privilege that matters is
   ordinary full-user-account privilege, not the entitlements.
3. **Self-update is the ongoing trust dependency.** Signature-verified against obdev's Team ID
   and a pinned key, which is strong — but the audited artifact can still replace itself.
   Addressed by Restriction 1.
4. **The activity log is locally readable by any app running as you** (`~/Library/Logs` is not
   TCC-protected). Addressed by Restriction 2.
5. **`x-microsnitch` URL scheme is registered** in `Info.plist`, so any web page or app can
   invoke it. Only the generic `application:openURLs:` handler is visible; **what it does with
   the URL cannot be determined statically.** Probable licence activation. **Unresolved.**
6. **`WebKit` is linked** into a menu-bar utility — probably the welcome/update/about panes. If
   it renders remote content, that is a meaningful parsing surface. **Not determinable
   statically.**
7. **The declared update endpoint could not be confirmed inside the binary** (see Phase 4).
8. **Update-control preference keys were not searched for.** The reviewer opted to record this
   as an open question rather than re-mount; it is answered directly by the Phase 5 procedure.
9. **CodeDirectory flags are `runtime` only** — no `kill`, `restrict` or `hard`.
10. **No provisioning profile exists**, so granted-vs-claimed could not be compared.

## Dealbreakers encountered

- **None.**

## Conditions / restrictions

These are **real conditions**, not preferences. The acceptance is contingent on both being
verified at first launch. **If either cannot be satisfied, the decision reverts to Hold.**

- **Restriction 1 — automatic update checking must be OFF.** Basis: the app can replace itself
  with a build that was never audited, and the reviewer requires that any new version pass the
  Appendix A baseline check first. *(The vendor's privacy policy §1.5.1 is phrased conditionally
  — "if you have activated 'Automatically check for updates'" — and the bundle ships an
  `ODSoftwareUpdate` preferences pane, so the control is expected to exist. **Not yet
  confirmed.**)*
- **Restriction 2 — the activity log must be OFF.** Basis: `~/Library/Logs/Micro Snitch.log` is
  unencrypted and not TCC-protected, so it is readable without prompt by any process running as
  the user. *(Release note 1.3 references "disabling the activity log," so the control exists.
  **Not yet confirmed in this version.**)*
- **Run from a user-writable location, not `/Applications`,** so the updater has no reason to
  invoke its admin-escalation path.

> **Why these *are* filed as restrictions.** In this framework a restriction means *"I am
> accepting a risk only because I have bounded it."* Both qualify exactly: self-update and local
> log exposure are real, identified risks, and the acceptance depends on bounding them.

## Operating notes (how this is run, not a condition of acceptance)

- **Re-check, don't re-audit.** On any new version, run
  [`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh) against the
  Appendix A baseline before installing. Full re-audit only if it reports drift.
- **Update cadence context:** roughly one release every 1–3 years. With automatic checking off
  per Restriction 1, check the vendor's release-notes page manually a few times a year.
- **Exposure-if-behind is low:** no inbound service, no listening port, no CVEs for this
  product, and its core function needs no elevated privilege. Staying on a known-good pinned
  version is a low-cost posture here. Software in the opposite quadrant — browsers, OS security
  updates, anything internet-facing — warrants the opposite policy.

## Decision rationale

Phase 4 settled what it can settle, and settled it cleanly: the bytes are provably those
Objective Development signed on 2023-09-13; the identity chains to Apple Root CA and matches a
Team ID obtained from the vendor **before** the file was examined; both Mach-O components share
that Team ID and a hardened-runtime configuration; nothing third-party is bundled; the one
bundled script is read-only and benign; and the product is **structurally incapable of capturing
audio or video**, on OS-enforced grounds rather than on trust.

What remained was not authenticity but **two capabilities the reviewer chose to bound rather
than accept open-ended**: the app can update itself, and it writes a locally-readable record of
microphone and camera activity. The reviewer initially recorded a **Hold**, then revised to
**Accept with restrictions** after two corrections: (a) the update check is documented by the
vendor as a user-controllable setting, not an unstoppable mechanism, and (b) **no evidence was
found that activity data is shared with the vendor** — the sole declared endpoint carries
version and licence metadata only, no third-party library or telemetry host exists in the
bundle, and the only domain in the binary is `obdev.at`.

**What this decision explicitly does not rest on:** signing and notarization prove the code is
*unmodified and from an identified party that passed Apple's automated malware scan* — they do
**not** prove the software is safe, honest, or free of vulnerabilities. Notarization is not a
code review. No compiled source was read, because none exists to read. **No runtime behaviour
has been observed yet.** All findings are point-in-time and apply to build 1337 only.

---

## Appendix A — recorded baseline

Machine-readable output of `scripts/verify-known-artifact.sh --record`, taken from the app
mounted read-only. A future version is checked with
`scripts/verify-known-artifact.sh --baseline <this file> <new app>`.

| Invariant | Value at 1.6.1 (1337) |
|-----------|----------------------|
| Bundle identifier | `at.obdev.MicroSnitch` |
| Team ID (all components) | `MLZF7K7B5R` |
| Signing authority (leaf) | `Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)` |
| Mach-O component count | **2** |
| CodeDirectory flags (both) | `0x10000` (runtime) |
| App notarization | stapled; Gatekeeper `accepted` |
| DMG notarization | **absent** (app is stapled instead) |
| Entitlements — main app | `device.audio-input`, `device.camera` (**inert; not sandboxed**) |
| Entitlements — login helper | `app-sandbox = 1` |
| Provisioning profile | none |
| Third-party linked libraries | none |
| Bundled scripts | 1 (`Resources/listdevices`, Perl, read-only) |
| Declared network endpoints | 1 (`sw-update.obdev.at:443/TCP`) |

```
# ECISF known-artifact baseline (schema 1)
# artifact: Micro Snitch.app
# This records what was true at audit time. It is evidence, not permission.
bundle-identifier	at.obdev.MicroSnitch
notarization	stapled
gatekeeper	accepted
component	Contents/MacOS/Micro Snitch
component	Contents/Library/LoginItems/Micro Snitch Open At Login Helper.app/Contents/MacOS/Micro Snitch Open At Login Helper
teamid	Contents/MacOS/Micro Snitch|MLZF7K7B5R
teamid	Contents/Library/LoginItems/Micro Snitch Open At Login Helper.app/Contents/MacOS/Micro Snitch Open At Login Helper|MLZF7K7B5R
authority	Contents/MacOS/Micro Snitch|Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)
authority	Contents/Library/LoginItems/Micro Snitch Open At Login Helper.app/Contents/MacOS/Micro Snitch Open At Login Helper|Developer ID Application: Objective Development Software GmbH (MLZF7K7B5R)
cdflags	Contents/MacOS/Micro Snitch|0x10000
cdflags	Contents/Library/LoginItems/Micro Snitch Open At Login Helper.app/Contents/MacOS/Micro Snitch Open At Login Helper|0x10000
entitlement	Contents/MacOS/Micro Snitch|"com.apple.security.device.audio-input" => 1
entitlement	Contents/MacOS/Micro Snitch|"com.apple.security.device.camera" => 1
entitlement	Contents/Library/LoginItems/Micro Snitch Open At Login Helper.app/Contents/MacOS/Micro Snitch Open At Login Helper|"com.apple.security.app-sandbox" => 1
```

> **Two notes for whoever runs the next comparison.**
> 1. The script's `nonapple-lib` heuristic excludes only `/System/Library/` and `/usr/lib/`, so
>    it records all 27 `@rpath/libswift*.dylib` entries as non-Apple. **They are Apple's Swift
>    runtime**, resolving via the `/usr/lib/swift` rpath because the bundle has no
>    `Contents/Frameworks`. Expected noise, omitted above for clarity — not a finding.
> 2. The script calls `xcrun stapler`. On a machine with only Command Line Tools active, bare
>    `stapler` fails with *"requires Xcode"*, but **`xcrun stapler` resolves correctly** to
>    `/Library/Developer/CommandLineTools/usr/bin/stapler` and works. Verified in this session.

## Appendix B — commands run (all read-only)

```
# Pre-mount, on the .dmg
shasum -a 256 <dmg>; xattr -l <dmg>; mdls -name kMDItemWhereFroms <dmg>
codesign --verify --deep --strict --verbose=2 <dmg>
codesign -dv --verbose=4 <dmg>
spctl -a -vvv -t open --context context:primary-signature <dmg>
xcrun stapler validate <dmg>
syspolicy_check distribution <dmg>
hdiutil imageinfo <dmg>; hdiutil verify <dmg>
curl -sIL <official download URL>            # confirm redirect to canonical path
curl -sL -o <tmp> <vendor URL>; cmp <tmp> <dmg>   # independent integrity comparison

# Tooling controls, run BEFORE trusting any negative result
spctl -a -vvv <known-notarized app>          # positive control
xcrun stapler validate <known-notarized app> # positive control
spctl -a -vvv <freshly-created unsigned file> # negative control

# Mount read-only (gated: only after the above, and with explicit consent)
hdiutil attach -readonly -nobrowse -noautoopen -mountpoint <mnt> <dmg>

# On the app and every nested component
codesign --verify --deep --strict --verbose=2 <app>
codesign -dv --verbose=4 <each of 4 targets>
codesign -d --entitlements - --xml <each of 4 targets>
spctl -a -vvv <app>; xcrun stapler validate <app>
plutil -p <app>/Contents/Info.plist
plutil -p <app>/Contents/Resources/InternetAccessPolicy.plist
otool -L <both binaries>; otool -l <binary> | grep -A2 LC_RPATH
nm -u <thin arm64 slice>            # imported symbols: capture vs. detect
strings -a <binaries> | grep -E …   # URLs, exec, persistence, sensitive paths
find <app> -type f -exec file {} \; # script detection by CONTENT, not extension
cat <app>/Contents/Resources/listdevices
openssl pkey -pubin -in <app>/Contents/Resources/ODSoftwareUpdatePublicKey.pem -text -noout

# security cms -D -i <embedded.provisionprofile>   -> N/A: no profile in this bundle

hdiutil detach <mnt>
shasum -a 256 <dmg>; xattr -l <dmg>   # confirm the artifact was not altered
```

## Update log (re-audits of later versions)

| Date | New version | What changed (diff summary) | Re-verdict |
|------|-------------|-----------------------------|-----------|
| | | | |
