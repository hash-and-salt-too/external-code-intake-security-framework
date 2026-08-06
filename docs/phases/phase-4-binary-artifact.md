# Phase 4 — Binary / Artifact Verification

**Question this phase answers:** *If I'm downloading a pre-built file, is it authentic, unmodified, properly signed and notarized, and asking only for permissions it should?*

You can't read a compiled binary, so trust comes from **cryptographic proof + Apple's checks + sane permissions** instead. This phase is macOS-focused because QLMarkdown and most Mac downloads are macOS artifacts.

> **The critical caveat, up front:** a valid signature and notarization prove the file is **authentic and un-tampered, and passed Apple's automated malware scan.** They do **not** prove the software is safe or honest. Pair this phase with Phase 1 (reputation) and Phase 5 (runtime). *Defense in depth.*

> Everything below is a **read-only inspection command** — it examines the file, it does not install or run it. Run these in Terminal against the file you downloaded. Seeing the commands is the point (nothing hidden); a helper script can bundle them later if you want.

---

## 4.1 Get the file from the right place, safely

- [ ] Download from the project's **official Releases page** over **HTTPS** — not a random mirror, ad, or re-upload.
- [ ] Grab any **published checksums or signatures** the project provides alongside the release.
- [ ] **Download with a browser, not `curl`.** The **quarantine** tag is what makes Gatekeeper evaluate a file on first open — and it is set by *quarantine-aware apps* (Safari, Chrome, Firefox, Mail, Messages), **not** by `curl`, `wget` or `git clone`. Fetching from the command line silently skips that check.
- [ ] Confirm the tag is present, and note which app set it:
  ```
  xattr -l <file>        # look for com.apple.quarantine
  ```
  The value reads `<flags>;<hex timestamp>;<app that downloaded it>;<UUID>`. A **missing** tag is not by itself evidence of tampering — it usually just means the file arrived by a route that doesn't set one (command line, USB, file share). Know which case you're in.
- [ ] **Don't strip it.** `xattr -d com.apple.quarantine` is the reflexive "fix" when something won't open. It disables the check this phase depends on.

---

## 4.2 Verify integrity with a hash (checksum)

A hash confirms your download matches what the maintainer published (no tampering in transit or on a mirror).

```
shasum -a 256 <file>     # prints the SHA-256 fingerprint
```
- [ ] Compare the output **character-for-character** against the value the project published.
- [ ] **Mismatch → stop.** The file isn't what the maintainer released.

> Limitation: if the *same page* provides both the file and its hash, a hash only protects against a *tampered download*, not a malicious *release*. A **signature** (next) is stronger because it ties the file to an identity.

---

## 4.3 Verify a cryptographic signature (if provided)

If the project signs releases (e.g. with GPG/PGP):
```
gpg --verify <file>.sig <file>
```
- [ ] Confirm the signature is **valid** *and* made by the maintainer's **known, trusted public key** (obtained independently — from their site/keyserver, not only from the same download page).
- [ ] "Good signature from an unknown key" is **not** enough — you must trust the key.

---

## 4.4 macOS code signing — *who* made it, and is it intact?

Code signing ties the app to a developer identity (a **Team ID**) and proves it hasn't changed since signing.

```
codesign --verify --deep --strict --verbose=2 <app-or-binary>
codesign -dv --verbose=4 <app-or-binary>      # shows Authority, Team ID, identifier
```
- [ ] `--verify` should report the signature is **valid / not modified**.
- [ ] In the `-dv` output, read the **Authority** chain (expect "Developer ID Application: … (TEAMID)") and note the **Team ID**. Does it match the maintainer you vetted in Phase 1?
- [ ] **"code object is not signed at all"** on something asking to run with real privileges is a strong red flag.

---

## 4.5 Notarization & Gatekeeper — did it pass Apple's malware check?

Notarization means Apple scanned the software and issued a ticket; Gatekeeper enforces this.

```
spctl -a -vvv <app>                    # assess an app (expect: accepted, source=Notarized Developer ID)
spctl -a -vvv -t install <installer>   # assess a .pkg/.dmg installer
stapler validate <app-or-dmg>          # confirm the notarization ticket is stapled
```
- [ ] Expect **"accepted"** and a **Notarized Developer ID** source.
- [ ] **"rejected"** or unsigned/un-notarized, for software that will run automatically or with privileges, is a serious finding.

---

## 4.6 Entitlements — *what powers is it asking for?*

Entitlements are the macOS equivalent of a permissions list. This is one of your most informative checks.

```
codesign -d --entitlements :- <app-or-binary>
```
- [ ] Read the requested entitlements and sanity-check them **against what the software claims to do**.
- [ ] For a Markdown previewer, reasonable might be limited file access; **unreasonable** would be things like microphone, camera, Address Book, or `com.apple.security.get-task-allow` (debugging) in a shipping build.
- [ ] Note whether the **App Sandbox** is enabled (`com.apple.security.app-sandbox`). Sandbox **on** is safer. If it requests **network** entitlements, ask why a local previewer needs the network.

> This directly implements **least privilege**: you're checking that the app asks only for the minimum it needs.

---

## 4.7 Peek inside the Mach-O (strings & linked libraries)

Not a full reverse-engineering effort — just quick, revealing looks:

```
otool -L <binary>        # dynamic libraries it links against
strings -a <binary> | sort -u | less   # readable text: URLs, paths, suspicious commands
nm <binary>              # symbols (function names), if not stripped
```
- [ ] In `otool -L`, note anything unusual beyond expected system frameworks.
- [ ] In `strings`, scan for **hardcoded URLs/IPs**, shell command fragments (`/bin/sh`, `curl`), sensitive paths (`~/.ssh`), or references to persistence — corroborating (or contradicting) Phase 3.

---

## 4.8 Installers (`.pkg`) — inspect *before* running

Installers can run scripts **as admin**. Never double-click one you haven't inspected.

```
pkgutil --check-signature <pkg>          # signing/notarization status of the installer
pkgutil --expand <pkg> <outdir>          # unpack it WITHOUT installing
#  → then read the Scripts: preinstall / postinstall inside <outdir>
```
- [ ] Read every **preinstall/postinstall** script. These run with elevated rights and are a favorite malware vector.
- [ ] Flag any script that fetches from the network, decodes blobs, installs launch agents/daemons, or writes outside the app's expected location.

For **`.dmg`**: mount it read-only, inspect the contents and any bundled installer with the steps above, and don't run anything blindly.

---

## 4.9 (Advanced, optional) Reproducible build

The strongest possible check: build from source yourself and confirm you get the *same* binary the maintainer published.

- [ ] If the project documents a reproducible build, following it lets you independently prove the binary matches the source you reviewed in Phase 3. Full reproducibility is still uncommon on macOS, so treat this as a bonus, not a requirement. When trust in a binary can't be established, **building from source (and running your own build) is the fallback.**

---

## Phase 4 outcomes

| Result | Meaning | Next |
|--------|---------|------|
| **Dealbreaker** | Hash/signature mismatch; unsigned *and* un-notarized while requesting privileges; installer script fetches/executes remote code or installs hidden persistence; entitlements wildly exceed function | **Reject.** |
| **Concerns** | Valid but from a Team ID you couldn't tie to the vetted maintainer; broader entitlements than expected; no published hash to compare | Corroborate via Phase 1 & 5; consider building from source instead. |
| **Clean** | Hash matches; validly signed by the expected Team ID; notarized/stapled; entitlements are minimal and sensible; installer scripts benign | Continue to runtime testing. |

Record findings, then continue to [`phase-5-runtime-sandbox.md`](phase-5-runtime-sandbox.md).
