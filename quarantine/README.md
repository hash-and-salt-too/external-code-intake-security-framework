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
- **Delete the contents when you're done.** Keep only your written report in
  [`../reports/`](../reports/).
- Never place secrets or credentials here.
