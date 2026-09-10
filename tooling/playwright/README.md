# KalaVistar mobile browser loop

Use the real Flutter Web application at fixed mobile viewports. The backend and
frontend stay in separate terminals so a Flask reload cannot interrupt the UI
session.

## Start the local stack

Terminal 1:

```powershell
Set-Location backend
python app.py
```

Terminal 2:

```powershell
.\tooling\start_mobile_web.ps1
```

The stable URLs are:

- Flutter Web: `http://127.0.0.1:7357`
- Flask API: `http://127.0.0.1:5000`

The repository also declares the lean browser pair in `.codex/config.toml`:
Playwright MCP for structured interaction, and Chrome DevTools MCP for visual,
console, network, and performance inspection. Restart the Codex desktop client
after the first checkout or any MCP configuration change so those tools are
loaded into the session.

## Primary 412 x 915 browser

```powershell
npx --yes --package @playwright/cli@latest playwright-cli -s=kalavistar-mobile open http://127.0.0.1:7357 --browser chrome --config tooling/playwright/mobile-412.json --headed
npx --yes --package @playwright/cli@latest playwright-cli -s=kalavistar-mobile snapshot
```

## Narrow 360 x 800 regression browser

```powershell
npx --yes --package @playwright/cli@latest playwright-cli -s=kalavistar-narrow open http://127.0.0.1:7357 --browser chrome --config tooling/playwright/mobile-360.json --headed
npx --yes --package @playwright/cli@latest playwright-cli -s=kalavistar-narrow snapshot
```

Keep the viewports in separate sessions. Resizing a running mobile-emulated
Flutter Web page can briefly produce invalid browser keyboard insets and is not
a trustworthy application regression.

Prefer `snapshot`, then `console`/`requests`, and use `screenshot` only for a
baseline, meaningful visual change, or checkpoint acceptance. CLI artifacts are
ignored by Git under `.playwright-cli/` and `output/playwright/`.

Mobile Chrome emulation validates responsive web UI only. Microphone, camera,
filesystem, share intent, Android back behavior, and other platform-channel
features still require native-device verification.
