# ScanMarket

[English](README.en.md) · [Русский](README.md)

> **Project status: active development.** The repository is large and still
> being finalized: parts of the source code and documentation are published in
> stages, and the structure and commands may change. Verify the instructions
> are current before use.

ScanMarket periodically reads items from your Ozon, Wildberries and Yandex
Market favorites and stores product information plus price history in SQLite.
A local GUI shows products, price history and charts.

The project is written in the Qode scripting language (Script) and ships with
the Qode Runtime, so it is ready to run right after cloning — no separate
installation is required.

## Contents

- [Features](#features)
- [System requirements](#system-requirements)
- [Qode Runtime](#qode-runtime)
- [Project layout](#project-layout)
- [Installation and first run](#installation-and-first-run)
- [Configuring config.json](#configuring-configjson)
- [Authorization and cookies](#authorization-and-cookies)
- [Running a scan](#running-a-scan)
- [Windows Task Scheduler](#windows-task-scheduler)
- [GUI](#gui)
- [Database and price history](#database-and-price-history)
- [Diagnostics](#diagnostics)
- [License](#license)

## Features

- Collects favorite items from Ozon, Wildberries and Yandex Market through a
  driven browser and the Chrome DevTools Protocol (CDP).
- Stores products, thumbnails and price history in SQLite.
- A new price point is recorded only when the price changes.
- Filters out ads and recommendation cards and handles anti-bot checks.
- Keeps authorization cookies and the browser profile under `private_data/`.
- Configures automatic runs through the Windows Task Scheduler (schtasks).
- Local GUI: product and history tables, product card, price chart, and a
  store switcher.

## System requirements

- Windows 10/11 (x64).
- A supported Chromium browser: Yandex Browser, Microsoft Edge or Google Chrome
  (used for authorization and scanning).
- Authorized accounts:
  - Ozon — [Favorites](https://www.ozon.ru/my/favorites);
  - Wildberries — [Favorites](https://www.wildberries.ru/lk/favorites);
  - Yandex — [Wishlist](https://market.yandex.ru/my/wishlist).
- Free disk space for the database and browser profile (hundreds of MB or more).
- Permission to create scheduler tasks (for automatic runs).

## Qode Runtime

ScanMarket is written in the Qode scripting language (Script), whose
capabilities are comparable to Python. Scripts need the Qode Runtime, which is
shipped in the `bin/` directory:

- `qode.exe` — console engine without Qt (for diagnostic utilities);
- `qodeqt.exe` — console engine with the Qt adapter and the `db` module (used
  for scanning and authorization);
- `qodegui.exe` — engine with GUI (runs `scanmarket_gui.json`);
- `qodedesigner.exe` — JSON form editor;
- `plugins/` — Qode plugins (http, websocket and others);
- `platforms/`, `imageformats/`, `sqldrivers/`, `styles/`, `tls/`,
  `iconengines/`, `generic/`, `networkinformation/`, `translations/` —
  Qt plugins and Qt 6.11.2 DLLs.

The Qode core is a component of this project; the compiled runtime is bundled,
and the source code is published as it becomes ready. Licensing: scripts,
libraries and the Qode Runtime use the MIT License (`LICENSE`); third-party
components are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Project layout

```text
.
├── ozon_auth.prg              # Ozon login and cookie save
├── ozon_check_session.prg     # authorized-favorites check
├── ozon_scan.prg              # scanning and price history
├── ozon_setup_cron.prg        # Windows scheduler task
├── wildberries_auth.prg       # Wildberries login and cookie save
├── wildberries_check_session.prg # Wildberries favorites check
├── wildberries_scan.prg       # Wildberries scanning
├── wildberries_setup_cron.prg # Wildberries scheduler task
├── yandexmarket_auth.prg      # Yandex login and cookie save
├── yandexmarket_check_session.prg # Yandex wishlist check
├── yandexmarket_scan.prg      # Yandex Market scanning
├── yandexmarket_setup_cron.prg # Yandex Market scheduler task
├── scanmarket.bat             # starts the GUI
├── scan_ozon.bat              # starts the Ozon scan (for the scheduler)
├── scan_wildberries.bat       # starts the Wildberries scan
├── scan_yandexmarket.bat      # starts the Yandex Market scan
├── auth_ozon.bat              # starts Ozon authorization
├── auth_wildberries.bat       # starts Wildberries authorization
├── auth_yandexmarket.bat      # starts Yandex Market authorization
├── config.json                # browser, stores, database, scheduler settings
├── config.example.json        # sample configuration (no personal data)
├── scanmarket_gui.json        # GUI form definition
├── bin/                       # Qode Runtime, Qt DLLs and plugins
├── lib/                       # project libraries (Script)
│   ├── config.prg             # configuration loading
│   ├── cdp.prg                # browser and Chrome DevTools Protocol
│   ├── dbstore.prg            # SQLite schema and data operations
│   ├── ozon.prg               # Ozon page parsing
│   ├── wildberries.prg        # Wildberries page parsing
│   ├── yandexmarket.prg       # Yandex Market page parsing
│   └── scanutil.prg           # diagnostic utility functions
├── scriptlib/                 # shared Script/Qode libraries (automation)
├── tools/                     # utilities
│   ├── scanutils.prg          # diagnostics and maintenance
│   ├── export_gui_data.prg    # exports Ozon data to JSON
│   ├── update_gui_stores.prg  # restores the store switcher in the GUI
│   └── gui_store_block.prg    # Script block for update_gui_stores.prg
├── test/                      # verification scripts
├── docs/                      # Script/Qode language documentation
├── LICENSES/                  # third-party license texts
├── THIRD_PARTY_NOTICES.md     # third-party components and licenses
└── private_data/              # PRIVATE data: databases, cookies, profile
```

The `private_data/` directory is created on first run and is excluded from Git.
It holds SQLite databases, cookies, the browser profile and diagnostic dumps.

## Installation and first run

1. Clone the repository or copy the project directory anywhere (a path without
   spaces is preferred but not required).

   ```bat
   git clone git@github.com:alexartrider/scanmarket.git
   cd scanmarket
   ```

2. Check that the Qode Runtime is in place:

   ```bat
   bin\qode.exe tools\scanutils.prg caps
   ```

   The command prints engine capabilities; exit code `0` means success. Qode
   utilities write output to `bin\log\` — check the logs if needed.

3. On first run, scripts create `config.json` with default values, or you can
   copy `config.example.json` to `config.json` and edit it.

4. Authorize the stores (see below) and run the first scan.

## Configuring config.json

`config.json` is created automatically on first run with default values. The
`config.example.json` sample contains all settings.

Key parameters:

| Parameter | Purpose |
| --- | --- |
| `browser.headless` | Run without a browser window (`0`/`1`). |
| `browser.execPath` | Path to `browser.exe`/`msedge.exe`/`chrome.exe`; empty means auto-detect. |
| `browser.debugPort` | Local Chrome DevTools Protocol port, default `9222`. |
| `browser.profileDir` | Browser profile directory, default `private_data/browser_profile`. |
| `browser.proxy` | Proxy: empty — system settings, `direct` — no proxy, otherwise the proxy address. |
| `ozon.favoritesUrl` | Ozon favorites page URL. |
| `ozon.waitLoginSeconds` | Maximum wait for login/page readiness. |
| `ozon.pageWaitSeconds` | Page load wait. |
| `ozon.maxScrollSteps` | Maximum number of scroll steps. |
| `ozon.stopTrailing` | Consecutive non-favorite cards threshold. |
| `ozon.chunk` | Cards per DOM query. |
| `wildberries.*` | Same settings for Wildberries (including `dbPath`). |
| `yandexmarket.*` | Same settings for Yandex Market (including `dbPath`). |
| `db.path` | Ozon database path, default `private_data/ozon/ozon.sqlite`. |
| `cron.taskName` | Scheduler task name for Ozon. |
| `cron.mode` | `daily` or `hourly`. |
| `cron.start` | Start time for `daily`, format `HH:MM`. |
| `cron.everyHours` | Interval in hours for `hourly`. |
| `cron.exe` | Task executable, usually `bin/qodeqt.exe`. |
| `cron.script` | Task script, usually `ozon_scan.prg`. |
| `cron.bat` | Task BAT launcher. |
| `cronWb.*`, `cronYm.*` | Same settings for Wildberries and Yandex Market. |

Scripts fill in missing parameters with defaults.

## Authorization and cookies

Each store is authorized separately. Cookies and the browser profile are stored
under `private_data/` and never enter the repository.

### Ozon

```bat
bin\qodeqt.exe ozon_auth.prg
```

A browser window opens. Sign in to Ozon and wait for the favorites list.
The script saves cookies to `private_data/ozon/ozon_cookies.json` and closes
the browser cleanly.

### Wildberries

```bat
bin\qodeqt.exe wildberries_auth.prg
```

Sign in to Wildberries and wait for the favorites. Cookies are saved to
`private_data/wildberries/wildberries_cookies.json` only if the favorites page
actually loaded (more than zero cards).

### Yandex Market

```bat
bin\qodeqt.exe yandexmarket_auth.prg
```

Sign in to Yandex. Cookies are saved to
`private_data/yandexmarket/yandexmarket_cookies.json` only if the wishlist
actually loaded.

Session checks:

```bat
bin\qodeqt.exe ozon_check_session.prg
bin\qodeqt.exe wildberries_check_session.prg
bin\qodeqt.exe yandexmarket_check_session.prg
```

## Running a scan

```bat
bin\qodeqt.exe ozon_scan.prg
bin\qodeqt.exe wildberries_scan.prg
bin\qodeqt.exe yandexmarket_scan.prg
```

The scripts open the browser with the saved profile, read favorite cards, update
the database under `private_data/<store>/`, save a snapshot to
`<store>_last_scan.json` and close the browser. If the store asks you to sign in
again, run authorization once more.

> Do not run several scans at the same time with one browser profile and one
> database.

## Windows Task Scheduler

For automatic runs, execute (for each store):

```bat
bin\qodeqt.exe ozon_setup_cron.prg
bin\qodeqt.exe wildberries_setup_cron.prg
bin\qodeqt.exe yandexmarket_setup_cron.prg
```

The scripts create a BAT launcher and a Windows scheduler task (schtasks). Task
settings come from the `cron`, `cronWb` and `cronYm` sections of `config.json`.
Run a task manually:

```bat
schtasks /run /tn "ScanMarketOzon"
```

## GUI

```bat
scanmarket.bat
```

The GUI opens `scanmarket_gui.json` via `bin\qodegui.exe`. The window shows
product and price-history tables, a card for the selected product with a
thumbnail, a price chart and a store switcher (Ozon / Wildberries / Yandex
Market). If the GUI was edited manually and the store switcher needs to be
restored, run:

```bat
bin\qodeqt.exe tools\update_gui_stores.prg
```

## Database and price history

SQLite databases live under `private_data/`:

- `private_data/ozon/ozon.sqlite`;
- `private_data/wildberries/wildberries.sqlite`;
- `private_data/yandexmarket/yandexmarket.sqlite`.

Main tables:

- `products` — products: source, product id, name, brand, link, status,
  thumbnail, favorite and tracking state;
- `price_points` — price history: price, old price, currency, availability, time;
- `scan_runs` — run log: found items, new points, status.

A new `price_points` row is created only when the price changes. The first
observation of a product creates the first point. Times use local computer time.

Export Ozon products and price history to JSON:

```bat
bin\qodeqt.exe tools\export_gui_data.prg
```

`private_data/scanmarket_view.json` contains names, links, statuses and price
history.

## Diagnostics

### `scanutils`

```bat
bin\qode.exe tools\scanutils.prg db
bin\qode.exe tools\scanutils.prg db private_data\wildberries\wildberries.sqlite
bin\qode.exe tools\scanutils.prg runs 20
bin\qode.exe tools\scanutils.prg points 20
bin\qode.exe tools\scanutils.prg tail 60
bin\qode.exe tools\scanutils.prg grep "auth_required"
bin\qode.exe tools\scanutils.prg cookies private_data\ozon\ozon_cookies.json
bin\qode.exe tools\scanutils.prg dump private_data\ozon\fav_challenge_dump.html
bin\qode.exe tools\scanutils.prg caps
```

`db`, `runs`, `points` and `fixstale` accept an optional trailing database path
(default: the Ozon database). `fixstale`, `procs`, `readmeinfo`, `cleanroot` and
`movefile` are also available.

### Module-load tests

```bat
bin\qodeqt.exe test\check_yandexmarket.prg
bin\qodeqt.exe test\run_tests.prg
```

### Logs

Engine logs are written to `bin\log\` (encoding may be CP1251). Old logs may
remain in `log/`.

### Common issues

| Problem | Solution |
| --- | --- |
| The store asks to sign in again | Run authorization (`*_auth.prg`) again. |
| Anti-bot check during a scan | Complete the check in the open browser window; the script continues on its own. |
| Products are not recognized | Check authorization, review `<store>_last_scan.json` and the logs. A zero result is not a success. |
| A utility exits with a non-zero code | A script error; check the logs in `bin\log\`. |

## License

The ScanMarket project (scripts, libraries, Qode Runtime, documentation) is
licensed under the MIT License — see [LICENSE](LICENSE).

Third-party components (Qt 6.11.2, OpenSSL 3.5.4, libc++/libunwind, Mesa
llvmpipe, etc.) are distributed under their own licenses. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the full list and
[LICENSES/](LICENSES/) for license texts.
