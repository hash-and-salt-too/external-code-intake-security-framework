# quarantine/ — staging for code under review

Put code you download for **static review** (reading) here. Everything in this
folder is **git-ignored** except this README, so downloaded payloads never get
committed.

## Rules
- **Never build or run** anything from this folder on your main machine.
  Compiling or executing untrusted code belongs in the isolated Phase 5
  environment (a VM or a throwaway macOS account) — see
  [`../docs/phases/phase-5-runtime-sandbox.md`](../docs/phases/phase-5-runtime-sandbox.md).
- Use this only to **read** source while working through
  [`../docs/phases/phase-3-source-review.md`](../docs/phases/phase-3-source-review.md).
- Running the **read-only** `scripts/check-build-feasibility.sh` against a folder
  here is fine — it only *reads* text and asks your selected tools for versions
  to find declared compatibility blockers. It never builds or runs the code,
  and a clear result is not permission to build.
- **Delete the contents when you're done.** Keep only your written report in
  [`../reports/`](../reports/).
- Never place secrets or credentials here.
