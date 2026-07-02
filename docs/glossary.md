# Glossary — Plain-Language Definitions

Every technical term used in this framework, explained for someone new to coding and GitHub. Skim it once, then come back whenever a word is unclear.

---

## GitHub and project basics

**Repository ("repo")**
A project's folder on GitHub. It holds the code, its history, and related files. Example: `github.com/sbarex/QLMarkdown` is a repository.

**Commit**
A single saved change to the code, like a snapshot with a note describing what changed. A healthy project has *many* commits over time from real people.

**Commit history**
The full timeline of commits. It's like a project's paper trail. A project with one giant "initial commit" and nothing else has *no* paper trail — a warning sign.

**Branch**
A parallel line of development. `main` (or `master`) is usually the primary one. You can ignore branches for most audits; just note which one you're looking at.

**Tag**
A bookmark on a specific commit, usually marking a version (e.g. `v1.4.2`). Tags are how projects mark "this exact code is release 1.4.2."

**Release**
A packaged version of the project that the maintainer publishes for people to download — often including a pre-built file (like a `.dmg`) plus release notes.

**Fork**
A personal copy of someone else's repository. Forks are normal, but "I'm downloading from a *fork* instead of the original project" deserves a second look — *why* this copy and not the original?

**Clone**
To download a full copy of a repository (code + history) to your computer, usually with the `git` tool. "Cloning" gives you the human-readable source code to inspect.

**Maintainer**
The person or team who runs the project and decides what code gets in. Your trust ultimately rests on them.

**Star / Fork count / Watchers**
GitHub popularity signals. Useful context, but **popularity is not safety** — popular projects get attacked precisely *because* they're popular, and stars can be bought.

**Issue**
A public report or discussion thread on the repo — bug reports, questions, feature requests. Lots of engaged issues = an active, watched project.

**Pull request ("PR")**
A proposed change submitted for the maintainer to review and merge. Shows how carefully changes are vetted.

**License**
The legal terms for using the code (MIT, GPL, Apache, etc.). A missing license is a minor red flag — a real project almost always has one.

---

## Code, building, and running

**Source code**
The human-readable instructions a programmer writes (in languages like Swift, C, Python, JavaScript). You *can read* source code to see what it does.

**Binary / executable**
The compiled, machine-ready version of a program. You *cannot easily read* a binary — it's not human-readable — so you must trust it in other ways (signatures, reputation) or build it yourself from source.

**Compile / build**
The process of turning source code into a runnable binary. "Building from source" means *you* do this on your machine.

**Toolchain**
The set of tools needed to build software (e.g. Apple's Xcode for macOS apps). "Building from source" requires the right toolchain installed.

**Interpreted vs. compiled**
*Interpreted* code (Python, JavaScript, shell scripts) runs directly from human-readable text — easy to inspect. *Compiled* code (C, Swift apps) is turned into a binary first — harder to inspect.

**Script**
A short, usually interpreted program (e.g. a `.sh` shell script or `.py` Python file). Scripts are easy to read but often run instantly with your full privileges.

---

## Dependencies and the supply chain

**Dependency**
Other people's code that a project needs in order to work. Almost every project has some. When you trust a project, you also trust all of its dependencies.

**Transitive dependency**
A dependency *of* a dependency. Projects can pull in hundreds of these indirectly. Each one is code you end up running.

**Package manager**
A tool that automatically downloads and installs dependencies for you: `npm` (Node.js), `pip` (Python), `gem` (Ruby), `cargo` (Rust), `brew` (macOS Homebrew), CocoaPods / Swift Package Manager (Apple). Convenient, but it pulls in trust automatically.

**Manifest file**
A file listing what a project depends on: `package.json`, `requirements.txt`, `Podfile`, `Cargo.toml`, `go.mod`, `Package.swift`. Your first stop for "what does this pull in?"

**Lockfile**
A file that pins the *exact* versions of every dependency (`package-lock.json`, `Podfile.lock`, `Cargo.lock`). Pinned versions are safer because they can't silently change under you.

**Vendored / bundled dependency**
Third-party code copied *directly into* the repository instead of downloaded separately. Example: QLMarkdown bundles the `cmark-gfm` C library. You should check that bundled code matches the trustworthy original and hasn't been secretly modified.

**Submodule**
A link from one Git repository to another, so one project can include another. Check *where* a submodule points — a link to a random personal repo is worth scrutinizing.

**Supply chain**
The entire chain of people, code, and infrastructure that produces the final thing you download: the maintainer, their dependencies, the build servers, GitHub itself. A "supply-chain attack" compromises you through one of these links rather than the main project directly.

**SBOM (Software Bill of Materials)**
A formal list of everything inside a piece of software — like an ingredients label. Some projects publish one; it makes auditing dependencies much easier.

---

## Trust, signing, and macOS specifics

**Hash / checksum (e.g. SHA-256)**
A short "fingerprint" calculated from a file. If even one byte changes, the fingerprint changes completely. Publishing a hash lets you confirm your download wasn't tampered with in transit. *Note:* a hash only proves the file matches what the maintainer posted — it does not prove the file is *safe*.

**Digital signature (e.g. GPG/PGP signature)**
Cryptographic proof that a file came from a specific person/key and wasn't altered. Stronger than a plain hash because it ties the file to an identity.

**Code signing (Apple)**
Apple's system where developers cryptographically sign their apps with an identity tied to a **Team ID**. Lets macOS confirm *who* made the app and that it hasn't been modified since.

**Notarization (Apple)**
An extra step where Apple scans a developer's app for known malware and issues a "ticket." Notarized apps have passed Apple's automated malware check. Not a full audit, but a meaningful baseline.

**Gatekeeper**
The macOS security feature that checks signing and notarization before letting downloaded apps run. When you see "macOS can't verify the developer," Gatekeeper is doing its job.

**Entitlements**
Specific permissions a macOS app requests — network access, camera, file access, disabling the sandbox, etc. Reading the entitlements tells you *what powers the app is asking for*. A Markdown viewer asking for the microphone would be suspicious.

**Sandbox**
A restricted "playpen" that limits what a program can touch (which files, whether it can use the network). Sandboxed code is safer. Some tools deliberately run *outside* the sandbox — note when and why.

**Quarantine attribute**
A hidden tag macOS puts on files you download from the internet (`com.apple.quarantine`). It's what triggers Gatekeeper's checks the first time you open something.

**Mach-O**
The file format of macOS executables. Tools like `otool`, `nm`, and `strings` can peek inside a Mach-O binary to see what libraries it links to and what text (like URLs) it contains.

**Quick Look extension**
A small macOS add-on that generates the preview you see when you press Spacebar on a file in Finder. **QLMarkdown** is one: it renders Markdown files into a preview. Because it runs automatically when you preview a file, it's worth auditing carefully.

---

## Attack and defense terms

**Threat model**
A clear picture of *what you're defending against* and *who might attack you*. Knowing this focuses your effort on what matters.

**Attack surface**
All the ways something could be attacked or could do harm. A read-only library has a small attack surface; an installer that runs as admin has a large one.

**Payload**
The malicious action a piece of bad code actually performs (stealing files, installing a backdoor, mining cryptocurrency).

**Persistence**
Techniques malware uses to keep running after you reboot or log out — e.g. installing a hidden background service (a "launch agent" on macOS), a login item, or editing your shell startup file.

**Exfiltration**
Secretly sending your data off your machine to an attacker, usually over the network.

**Obfuscation**
Deliberately making code hard to read to hide what it does — e.g. long random-looking strings, `base64`-encoded blobs, or minified code where a library wouldn't be. In something you're auditing, obfuscation is itself a warning sign.

**Backdoor**
Hidden functionality that lets someone bypass normal security — e.g. a secret password or a way to run remote commands.

**Typosquatting**
Publishing a malicious project under a name that looks almost like a popular one (e.g. `qlmarkdwn` vs `QLMarkdown`), hoping you install the wrong one by mistake.

**Reproducible build**
When building the same source code always produces a byte-for-byte identical binary. It lets anyone independently confirm that a published binary really came from the published source. Still uncommon on macOS, but a strong trust signal when available.

**CI/CD (Continuous Integration / Continuous Delivery)**
Automated systems (like GitHub Actions) that build, test, and publish software. Convenient, but they're part of the supply chain — a compromised build pipeline can poison an otherwise clean project.
