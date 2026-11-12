# Commercialization audit

Status: assessment complete · decision `2026-10-auth-1` in force · no paid edition.

This document answers issue #28. It classifies PodLens, inventories any
existing rights/payment/trial code, and records why the shared Permit and
Commerce contracts are **not** integrated. It is an implementation gate, not
permission to turn on billing.

Authoritative policy read for this audit:

- [`PRICING.md`](../PRICING.md) — `2026-10-auth-1` (2026-10-23), free BYOK,
  no Permit/Commerce product gate.
- [`AGENTS.md`](../AGENTS.md) — authorization preamble and portfolio
  placement (`2026-10-v2`).
- Product contract: [`racket/backend.rkt`](../racket/backend.rkt) and
  [`docs/DESIGN-ROADMAP.md`](DESIGN-ROADMAP.md).
- Repository state audited at `cc6262db26ec10fc29c72422a1fbd8a57b638442`
  plus the 0.6.0 work in this branch (redesign, secure BYOK storage,
  cancellation, settings contract).

## 1. Classification

| Question | Answer |
|---|---|
| What ships? | A native desktop podcast listening/reading application for macOS 14+, Windows 10+ and Linux; a shared Racket core exposed as typed RPC, plus an agent-friendly CLI. |
| Who pays for model usage? | The user, directly to their own OpenAI-compatible provider (BYOK). PodLens never proxies, resells or hosts model capacity. |
| Is there a paid edition? | No. Every shipped feature is free: feeds, playback, transcription, translation, summaries, caches, CLI and export. |
| Is there a subscription, trial, seat or device licence? | No. |
| Is there any payment or entitlement code? | No. No Permit verifier, no Commerce client, no checkout URL, no issuer key and no trial clock exists in the tree. |
| What is the source licence? | GNU AGPL-3.0 (`LICENSE`). Source rights are independent of an official build, update feed or support service. |
| What is the commercial service, if any? | None at launch. Signed updates and OS publisher trust are distribution integrity, **not** a paid entitlement. |

Grep evidence from the tree at the audited revision: no matches for
`Permit`, `Commerce`, `checkout`, `license-key`, `activation` or `trial`
outside documentation that explicitly forbids them. `PRICING.md` is the only
place a future price is mentioned, and it marks prices as launch targets,
not live offers.

## 2. User-data and rights obligations

Even with no paid tier, a commercial product must protect the user's own
library. These are implemented and must remain free:

- **Export/recovery** — library and transcripts remain ordinary files under
  `~/.podlens`; the CLI exports Markdown transcripts; no purchase or account
  is required to read, back up or move data.
- **Credential ownership** — the BYOK key belongs to the user. It is stored
  in the OS vault where available (macOS Keychain, Windows DPAPI, Linux
  Secret Service) and only falls back to an owner-readable `0600` file with
  an explicit warning. It is never written to `config.json`, logs, CLI
  output or diagnostics after migration.
- **Provider choice** — no PodLens account, no mandatory hosted AI, no
  bundled minutes. A user can switch provider by changing a base URL.
- **Offline use** — playback, cached transcripts and exported text work
  without a network connection; update checks are optional and signed.
- **Source rights** — AGPL-3.0 remains unchanged. Nothing in a commercial
  plan may revoke rights already granted for a released source revision.

## 3. Decision on Permit / Commerce

**Do not integrate either contract now.**

Rationale, per `2026-10-auth-1`:

1. There is no approved paid edition and no commercial service to gate.
2. Imposing a paid gate on a free tool would reduce trust without validated
   value; the current priority is repeat weekly listening and usability.
3. A client-side licensing authority would duplicate the future hosted
   Commerce/Permit authority and create a second source of truth.
4. Adding trial/licence UI now would be untestable against a real offer and
   would violate the honesty rule that unimplemented commercial features are
   not described as shipped.

Consequently:

- No Permit verifier in the hosts or the shared core.
- No Commerce checkout, payment evidence, issuer/claim/restore flow.
- No device/seat limit, licence account, activation or trial clock.
- No secrets for payment or signing in the client. Update signing keys stay
  release-only and are verified, never issued, by the app.

## 4. When a paid edition is proposed

A future paid edition must pass this gate **before** any UI claims it exists:

1. Record a new policy revision in `PRICING.md` and the authorization
   preamble; do not reuse `2026-10-auth-1` for paid work.
2. Define feature identities and the free floor. Reading, exporting,
   backing up and recovering the user's own data stay free.
3. Put rights verification in the shared core through Permit Protocol v1;
   hosts never implement their own signer, issuer or payment authority.
4. Put the offer and authenticated payment evidence in the hosted Commerce
   service; no secrets in the client. Link central
   [commerce#27](https://github.com/turlamai/commerce/issues/27) and
   [permit#15](https://github.com/turlamai/permit/issues/15) in the design
   record.
5. Prove the provider sandbox end-to-end before announcing sales.
6. Test, on each shipped platform: valid, counterfeit, expired,
   wrong-product, revision mismatch, offline use, restore, refund, upgrade
   and update continuity — with real data migration from the free version.
7. Publish the result as implemented/released/verified honestly. A plan is
   not a shipped feature.

Until then, a plan or price in a document is a target, not a live offer, and
must never enable a purchase link, trial or activation prompt.

## 5. What changed in 0.6.0 for this audit

- BYOK storage moved out of plaintext `config.json` into the OS vault with a
  documented fallback and one-time migration (`#13`).
- The settings surface masks the credential; echoing the mask back is a
  no-op, so old host save loops cannot overwrite or leak it.
- CLI `config` output and save echoes mask the key; doctor reports the
  storage backend without reading the value.
- Diagnostics never print the key; the update path remains signed and
  independent of any product licence.

No permit, commerce or trial code was added. The classification remains
**free BYOK application with no paid edition**.

## 6. Verification status

| Check | Status |
|---|---|
| Source inventory for rights/payment code | Done (this document) |
| Policy revision recorded | `2026-10-auth-1`, 2026-10-23 |
| Permit integration | Not applicable — intentionally absent |
| Commerce integration | Not applicable — intentionally absent |
| Provider sandbox proof | Not applicable until a paid service exists |
| Export/recovery/credential protections | Implemented and covered by backend tests |
| Real payment evidence | None claimed |

Owner: the next commercial slice. Re-read `PRICING.md` and this document at
that boundary; do not treat this audit as permission to enable billing.
