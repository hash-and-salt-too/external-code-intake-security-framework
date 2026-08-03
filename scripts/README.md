# scripts/ — small, read-only helpers

Helper scripts for the intake framework. Everything here is **read-only by
design**: these tools *gather evidence and answer a question* — they never
install, build, or run the external code you're reviewing. The intake gate stays
on **execution**, and a **human still owns every decision** (see
[`../docs/00-scope-and-boundaries.md`](../docs/00-scope-and-boundaries.md)).

---

## `check-build-feasibility.sh` — declared compatibility preflight

**The problem it solves.** Building from source only helps if your toolchain can
compile the version you're reviewing. Your installed **Xcode** sets a ceiling on
the **Swift version** and **SDK** you can build against, and a project's newest
release may require a newer one. Without checking first, you can spend real time
on a build that was never going to succeed — or be tempted into risky
workarounds. This script looks for **declared blockers** in a few seconds,
*before* you commit to the build-from-source path. It cannot prove a build will
succeed: source may use newer Swift features or SDK APIs that static metadata
does not declare.

### Usage

```bash
# default: checks the quarantine/ folder
scripts/check-build-feasibility.sh

# or point it at a specific downloaded project
scripts/check-build-feasibility.sh quarantine/some-project

# if several build files are reported, select the one you intend to use
scripts/check-build-feasibility.sh quarantine/some-project \
  --build-file path/to/Package.swift
```

### What it reads

- **Your selected toolchain** (asks your own tools): developer directory, Xcode
  version, Xcode-selected Swift version, and installed macOS SDK. It warns if a
  different Swift on `PATH` could make results misleading.
- **What the project requires** (plain-text reads only): the
  `swift-tools-version` from the top of `Package.swift`, any `.swift-version` /
  `.xcode-version` pin, Xcode project files, workspaces, `.xcconfig` files, and
  the macOS **deployment target**. The deployment target is reported only as
  the minimum runtime OS; it is not treated as a required SDK version.

### What it tells you

| Exit | Meaning | Next step |
|:----:|---------|-----------|
| `0` | **No declared blocker found** | Continue Phase 2 + Phase 3 review. This is neither proof of build success nor permission to build; wait for the recorded human decision. |
| `1` | **Declared blocker found** | Do not force the build. Keep reviewing readable source. A pre-built artifact needs Phase 4 and risk-appropriate Phase 5, and may still end in Hold or Reject. |
| `2` | **Inconclusive** | Resolve the warnings before choosing a build path. Do not build or run anything. |

If you consider an **older release**, pin and review that exact version. Check
advisories and the changelog for security fixes made after it. Reviewing older
source does not establish that a newer pre-built binary matches that source.

### Why it's safe to run on quarantined code

A SwiftPM `Package.swift` is itself Swift code. Asking SwiftPM to parse it
(`swift package …`) would **execute** it — exactly what the framework tells you
not to do before a decision. This script **never** does that: it reads the
required version from the file's header comment as plain text. It runs no part of
the target project, so it's safe to use on code sitting in
[`../quarantine/`](../quarantine/) during Phase 1–3 review.

> **Your selected Xcode sets the ceiling.** The script detects the currently
> selected versions instead of relying on a hardcoded machine configuration.
> A dated record of the environment that prompted this helper lives in the
> [Xcode design record](../docs/design-decisions-Xcode.md).

### Test the helper

```bash
scripts/tests/check-build-feasibility-tests.sh
```

The test suite uses temporary fixtures and mocked tool-version output. It does
not build or execute external code.
