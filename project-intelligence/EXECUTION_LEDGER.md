# KalaVistar execution ledger

Concise record of autonomous roadmap checkpoints. Temporary screenshots stay
outside the repository.

## Mobile browser harness — complete

- Main finding: a fixed Flutter `web-server` URL plus fixed mobile browser
  contexts is reliable; resizing an active mobile-emulated Flutter page can
  trigger a false negative-insets assertion.
- Files changed: `.codex/config.toml`, `.gitignore`,
  `tooling/start_mobile_web.ps1`, and `tooling/playwright/*`.
- Validation: both JSON configs parsed; Playwright reported exactly `412 x 915`,
  touch enabled, and a mobile Android user agent; `codex mcp list` recognized
  Playwright MCP and Chrome DevTools MCP; Flask health returned `ok` on port
  5000 and Flutter returned HTTP 200 on port 7357.
- Browser viewport tested: `412 x 915`; the `360 x 800` fixed context is
  configured and awaits its first post-restart regression pass.
- Visual iteration count: 2.
- Commit SHA: `a11c8fe`.
- Remaining native-device-only verification: microphone permission/recording,
  camera/plugin behavior, filesystem paths, share intent, and Android back/OS
  integration remain outside browser evidence.

## Ranked findings entering C1

- NOW: unify the unauthenticated demo artisan identity across Home, Catalog,
  Orders, and Analytics; replace hardcoded Home metrics with live or explicitly
  labelled baseline data; expose analytics provenance and honest states.
- NOW: give simultaneously mounted floating action buttons unique Hero tags to
  remove the runtime collision on the artisan shell.
- LATER: authorize `127.0.0.1` in Firebase only if popup/redirect OAuth becomes
  part of the judged browser path; email/password and demo access do not require
  that external-console change today.
- POST-SIH: no new candidate from this checkpoint.
