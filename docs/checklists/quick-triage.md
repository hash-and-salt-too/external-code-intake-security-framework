# Quick Triage Checklist (10–15 minutes)

A fast **go / no-go** before you invest in a full audit. Most bad or low-quality downloads get filtered out here.

**How to use:** Answer each item. **Any "❌ / dealbreaker" → stop and reject** (*fail closed*). Several "⚠️ concern" answers → proceed only with a full audit and strong isolation. All clear → proceed based on risk (low-risk items may not need more).

> This is a filter, **not** a full audit. Anything that will run with real privileges on your machine — installers, system extensions, **QLMarkdown** — always warrants the full audit regardless of how clean triage looks.

---

## A. Is it the real thing?
- [ ] The `owner/repo` is the genuine project (no typosquat/lookalike). *Mismatch → ❌*
- [ ] I reached it via a trustworthy link (official site/docs), not a random ad, DM, or search result.
- [ ] If it's a **fork**, I know *why* I'm using the copy and not the original. *No good reason → ⚠️*

## B. Is the project real and alive?
- [ ] Real commit **history** over time (not a single "initial commit" dump). *Single dump → ⚠️/❌*
- [ ] Maintained recently enough to get security fixes (or I accept the maintenance risk).
- [ ] Issues are **enabled** and there's genuine community activity. *Issues disabled + asks me to run code → ⚠️*

## C. Are the people credible?
- [ ] The maintainer has an established account and a track record beyond this one repo. *Brand-new throwaway account → ⚠️/❌*
- [ ] No signs of a recent account takeover (sudden maintainer change, force-rewritten history, out-of-character activity).

## D. Basic hygiene
- [ ] Has a `LICENSE`.
- [ ] README honestly explains what it does and what access it needs.
- [ ] No pressure/urgency to "just install it," and no hostility toward scrutiny. *Pressure → ⚠️*

## E. Obvious danger signs (any one = stop)
- [ ] Install instructions are **not** a blind `curl … | bash` / `curl … | sudo bash` one-liner. *Piping remote script straight to shell → ❌ unless I download and read it first.*
- [ ] Nothing here asks me to **paste secrets, disable security (Gatekeeper/SIP), or grant admin** for no clear reason. *→ ❌*
- [ ] No obviously **obfuscated** code or `base64` blobs presented as "the installer." *→ ❌*
- [ ] A quick web search for `"<name>" malware/scam/security` surfaces no serious unresolved reports. *Serious reports → ❌*

## F. Pin it
- [ ] I've identified the **exact version/tag/commit** I'll audit and use.

---

## Triage verdict

- **❌ Any dealbreaker** → **Reject.** Done.
- **⚠️ One or more concerns** → Proceed to the **full audit** ([`full-audit.md`](full-audit.md)) with heightened scrutiny and strong isolation; prefer building from source.
- **✅ All clear** →
  - *Low-risk artifact* (read-only library in a test project, sandboxed, easily inspected): a light review may suffice.
  - *Medium/high-risk artifact* (**anything running with real privileges — includes QLMarkdown**): continue to the **full audit**.

Next: [`full-audit.md`](full-audit.md) · Watch-list: [`red-flags.md`](red-flags.md)
