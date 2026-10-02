![SelfMemer](docs/selfmemer.png)

<p align="center">
  <img src="https://img.shields.io/github/stars/iamsoln/selfmemer?style=flat-square">
  <img src="https://img.shields.io/github/forks/iamsoln/selfmemer?style=flat-square">
  <img src="https://img.shields.io/github/issues/iamsoln/selfmemer?style=flat-square">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square">
  <img src="https://img.shields.io/github/last-commit/iamsoln/selfmemer?style=flat-square">
  <img src="https://img.shields.io/badge/node-%3E%3D18-339933?style=flat-square&logo=node.js&logoColor=white">
  <img src="https://img.shields.io/badge/python-%3E%3D3.10-3776AB?style=flat-square&logo=python&logoColor=white">
</p>

<h1 align="center">SelfMemer Dashboard</h1>

<p align="center">
  Self-hosted, multi-account automation dashboard for Dank Memer on Discord.<br>
  Run any number of accounts from one web UI — commands, market sniping, balance tracking,<br>
  mothership transfers, and anti-detection built in.
</p>

<p align="center">
  <a href="#quickstart"><b>Quickstart</b></a> ·
  <a href="#features">Features</a> ·
  <a href="#project-structure">Structure</a> ·
  <a href="#configuration">Configuration</a> ·
  <a href="#api-reference">API</a> ·
  <a href="#screenshots">Screenshots</a>
</p>

<p align="center">
  Join the <a href="https://discord.gg/bbRynPZpq">Support Server</a>
</p>

---

## Quickstart

**Requirements:** Node.js 18+, Python 3.10+, a Discord account with a valid user token.

```bash
git clone https://github.com/iamsoln/selfmemer.git
cd selfmemer

cp config.example.json config.json   # then fill in your token + channel id
make install                         # installs npm deps + flask (or: npm install && pip install -r requirements.txt)

npm start                            # starts bots + dashboard together
```

Open **http://localhost:5000**. The dashboard connects to your accounts and begins running enabled commands immediately.

| Command | What it does |
|---|---|
| `npm start` | Run everything (bots + dashboard) — same as `bash start.sh` / `make run` |
| `npm run bots` | Run only the bot processes (`node bot/manager.js`) |
| `npm run dashboard` | Run only the web dashboard (`python3 server/server.py`) |
| `make install` | Install Node + Python dependencies |
| `make test` | Syntax-check all JS + Python sources |

## Features

| Area | What you get |
|---|---|
| **Multi-account** | Each account gets its own isolated bot process, balance tracker, and dashboard tab |
| **Fleet overview** | Combined wallet / bank / net-worth totals, per-account doughnut charts, ranked leaderboard |
| **Commands** | Live toggles for hunt, dig, search, beg, crime, higher/lower, post meme, adventure, fishing, daily, work, deposit, trivia, stream, pet — no restart needed |
| **Market Sniper** | Scans `pls market view` and buys coin listings below your max price per item |
| **Fishing mode** | Exclusive loop with live catch stats, per-species chart, configurable sell currency; turning it off restores your previous toggles |
| **Balance tracking** | 30-second polling with historical wallet / bank / net-worth charts |
| **Mothership transfers** | One account receives; support vessels send inventory + wallet via friends share or market post |
| **Stealth** | Strict / Moderate / Casual / Fast presets — typing simulation, one-sided cooldown jitter, uptime/downtime cycling |
| **Browser fingerprint** | Always-on Chrome 103 / Chrome OS UA, `x-super-properties`, `Sec-*` headers, dynamic Referer |
| **Risk mode** | Low / Medium / High / Custom search & crime ordering with drag-to-reorder lists |
| **Adventure** | Plays your chosen adventure end-to-end, auto-calculates cooldown, optional custom answers |
| **Activity log** | Live feed with All / Main / Balance / Warnings filters and per-entry source tags |

## Project Structure

```
SelfMemer/
├── bot/                    # Discord automation (Node.js)
│   ├── manager.js          # Spawns + supervises one bot per account, watches config.json
│   ├── main.js             # Command loops, sniper, transfers, stealth per account
│   ├── bal_tracker.js      # Balance / net-worth polling → balance_<id>.json
│   ├── fish_detector.js    # Fishing-grid image analysis
│   └── logger.js           # Log shipping to the dashboard API
├── server/                 # Dashboard backend (Python)
│   └── server.py           # Flask app on :5000 — REST API + serves web/
├── web/                    # Dashboard frontend (no build step)
│   ├── index.html
│   ├── scripts.js
│   └── styles.css
├── data/
│   └── trivia.json         # Trivia answer database
├── docs/                   # Screenshots
├── config.json             # YOUR secrets — gitignored, never commit
├── config.example.json     # Template — copy to config.json to start
├── requirements.txt        # Python dependencies (flask)
├── package.json            # Node dependencies + npm scripts
├── Makefile                # install / run / bots / dashboard / test
└── start.sh                # Launches bots + dashboard with cleanup
```

**Runtime files** (all gitignored, all live in the project root): `balance_<id>.json`, `fish_stats.json`, `sniper_stats.json`, `*.lock`, `*.flag`, `transfer_trigger_*.json`, `transfer_status_*.json`, `market_pending_*.json`, `cycle_<id>.json`.

**How the pieces talk to each other:**
- `bot/manager.js` watches `config.json` every 2 s and restarts only the accounts whose connection changed — no full restarts. After 5 crashes in 90 s it backs off to 60 s restarts.
- `bot/main.js` and `bot/bal_tracker.js` POST logs/stats to the Flask API over localhost HTTP.
- A file-based interaction lock keeps `bal_tracker` from sending `pls bal` mid-command.
- Transfer trigger files let the dashboard request a mothership transfer; `main.js` picks them up on its next cycle.
- Config hot-reload: `main.js` re-reads `config.json` every 5 s and applies changes without restarting.
- Every command loop is supervised — a transient Discord error restarts that loop after 5 s instead of silently killing the feature.
- The uptime/downtime cycle persists to `cycle_<id>.json`, so a restart mid-downtime resumes the rest window.
- CAPTCHA detection pauses the bot until you solve it and click **Resume bot** (`POST /api/accounts/<id>/resume`).
- Fish/sniper session stats persist across server restarts; enabling the feature resets its session timer.
- Debug market probe only runs with `SELFMEMER_MARKET_STUDY` set, e.g. `SELFMEMER_MARKET_STUDY=apple npm start`.

## Configuration

`config.json` is gitignored — it holds your Discord tokens. Copy the template and edit:

```bash
cp config.example.json config.json
```

### Account fields

| Field | Type | Default | Description |
|---|---|---|---|
| `id` | string | — | Unique identifier. Example: `acc-1` |
| `name` | string | — | Display name in the dashboard |
| `token` | string | — | Discord user token |
| `channel_id` | string | — | Channel where Dank Memer commands are sent |
| `bot_id` | string | `270904126974590976` | Dank Memer's bot ID |
| `discord_uid` | string | `""` | Auto-populated on first run. Leave blank |
| `bal_tracker_enabled` | boolean | `true` | Run balance tracker for this account |
| `cooldown` | number | `20` | Seconds between hunt / dig commands |
| `search_cooldown` | number | `25` | Seconds between search commands |
| `beg_cooldown` | number | `40` | Seconds between beg commands |
| `crime_cooldown` | number | `40` | Seconds between crime commands |
| `hl_cooldown` | number | `10` | Seconds between higher/lower commands |
| `hl_wait_for` | number | `5` | Seconds to wait for a higher/lower response |
| `pm_cooldown` | number | `20` | Seconds between post meme commands |
| `wait_for_response` | number | `10` | Command response timeout in seconds |
| `adv_cooldown` | number | `1800` | Base adventure cooldown in seconds |
| `daily_cooldown` | number | `86400` | Seconds between daily claims |
| `work_cooldown` | number | `3600` | Seconds between work shifts |
| `deposit_cooldown` | number | `60` | Seconds between deposit runs |
| `trivia_cooldown` | number | `10` | Seconds between trivia plays |
| `stream_cooldown` | number | `660` | Seconds between stream sessions |
| `pet_cooldown` | number | `1800` | Seconds between pet care runs |
| `adv_type` | string | — | Adventure name exactly as shown in-game |
| `search_risk` | string | `medium` | `low`, `medium`, `high`, or `custom` |
| `crime_risk` | string | `medium` | `low`, `medium`, `high`, or `custom` |
| `fish_sell_currency` | string | `coins` | `coins` or `tokens` |
| `disable_interaction_lock` | boolean | `false` | Disable the single-command mutex (premium servers) |
| `commands_enabled` | object | — | Keys: `hunt` `dig` `search` `beg` `crime` `hl` `pm` `adv` `fish` `daily` `work` `deposit` `trivia` `stream` `pet`. Values: `true`/`false` |
| `market_sniper_enabled` | boolean | `false` | Enable the market sniper |
| `market_sniper_cooldown` | number | `30` | Seconds between full market scans |
| `market_sniper_items` | array | `[]` | Watch list — see below |
| `market_study_item` | string | `apple` | Item used for market price research (debug probe only) |
| `limit_flags` | boolean | `false` | Enable behavioral anti-detection (typing delays, jitter, cycling) |
| `stealth_mode` | string | `moderate` | `strict`, `moderate`, `casual`, or `fast` |
| `cycle_uptime_mins` | number | `0` | Minutes to run before pausing. 0 = disabled |
| `cycle_downtime_mins` | number | `0` | Minutes to pause before resuming. 0 = disabled |

### Market sniper item entry

```json
{
    "name": "lifesaver",
    "max_price": 200000,
    "buy_qty": 5
}
```

`name` must match the item name exactly as Dank Memer displays it. `max_price` is coins per unit. `buy_qty` caps quantity per snipe event.

### Stealth mode presets

| Mode | Typing chance | Typing delay | CD variance | Speed |
|---|---|---|---|---|
| `strict` | 100% | 700–1400ms | +0–35% | Slowest |
| `moderate` | 80% | 300–600ms | +0–20% (biased low) | Moderate |
| `casual` | 40% | 100–300ms | +0–10% (heavily biased) | Fast |
| `fast` | 0% | None | None | Maximum |

The cooldown variance is one-sided — it only ever *adds* 0–variance% to the configured cooldown, never shortens it.

Browser fingerprint headers (Chrome 103 / Chrome OS UA, `x-super-properties`, all `Sec-*` headers) are **always active** and unaffected by `limit_flags` or stealth mode.

### Root fields

| Field | Type | Description |
|---|---|---|
| `accounts` | array | List of account objects |
| `mothership_id` | string or null | `id` of the account that receives transfers |

## API Reference

Base URL: `http://localhost:5000`. Selected endpoints:

| Method | Endpoint | Purpose |
|---|---|---|
| GET/POST | `/api/accounts` | List / create accounts |
| PUT/DELETE | `/api/accounts/<id>` | Update / delete an account |
| GET/DELETE | `/api/accounts/<id>/balance` | Balance history / reset it |
| POST | `/api/accounts/<id>/bal-tracker` | Toggle the balance tracker |
| POST | `/api/accounts/<id>/resume` | Clear a CAPTCHA pause |
| POST | `/api/accounts/<id>/transfer` | Start a mothership transfer |
| GET | `/api/accounts/<id>/transfer-status` | Poll transfer progress |
| GET/POST | `/api/accounts/<id>/market-sniper` | Sniper watch list + interval |
| GET/DELETE | `/api/market-sniper-stats/<id>` | Sniper buy history / reset |
| GET/DELETE | `/api/fish-stats/<id>` | Fishing session stats / reset |
| GET/POST/DELETE | `/api/mothership` | Fleet command account |
| GET | `/api/overview` | Fleet-wide wallet / bank / net-worth |
| GET | `/api/status` | Online heartbeats per process |
| GET | `/api/logs?account=<id>&since=<ts>` | Activity log feed |

## Getting your Discord token

1. Open Discord in a **web browser** at `discord.com`. Do not use the desktop app.
2. Press `F12` to open developer tools.
3. Go to the **Network** tab and set the filter to **Fetch/XHR**.
4. Send any message in any channel.
5. Click one of the requests that appears. Open **Headers** → **Request Headers** and find `Authorization`. That value is your token.

> Your token gives complete access to your Discord account. Never share it, never commit `config.json`, and never paste it anywhere except your local config file.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Bot restarts every 5–60 s | Bad token or channel ID | Check the account log in the dashboard; fix Connection settings |
| `config.json missing` on start | First run | `cp config.example.json config.json` |
| Balance chart empty | Tracker disabled or no reply yet | Enable Balance Tracker; wait ~40 s for the first `pls bal` |
| CAPTCHA pause won't clear | CAPTCHA unsolved | Solve it in Discord, then click **Resume bot** |
| Market study spam in logs | Debug probe enabled | Unset `SELFMEMER_MARKET_STUDY` and restart |
| Port 5000 in use | Another dashboard running | Stop the other instance or change the port in `server/server.py` |

## Security

- `config.json` is gitignored and never committed
- Balance history, stats caches, locks, flags, and transfer triggers are all gitignored
- No credentials are logged or sent anywhere except directly to Discord
- The Flask server binds to `0.0.0.0:5000` — if you expose this port externally, put authentication in front of it

## Development

```bash
make test     # syntax-check all JS + Python sources
```

There is no test suite yet — contributions welcome.

## Screenshots

### Fleet Overview

Combined totals across all accounts. The two doughnut charts break down wallet+bank balance and net worth per account. Auto-refreshes every 30 seconds.

![Fleet Overview](docs/overview.png)

### Account Leaderboard

Sorted by net worth descending. Shows the mothership crown, online status, wallet, bank, net worth, and how recently each account's balance was updated.

![Account Leaderboard](docs/leaderboard.png)

### Mothership Transfer

Support vessels can send items via Friends Share, items via Market Post, coins directly, or coins via Market Post. A notice reminds you to pause command handlers and have enough coins for market taxes before starting.

![Mothership Transfer](docs/transfer.png)

### Connection & Bot Status

Account credentials, one-click save-and-restart, and live status cards. Browser Fingerprint is always active, independent of any toggle.

![Connection and Bot Status](docs/connection.png)

### Mothership — Primary Account

The designated mothership account is highlighted. Other accounts can transfer their full inventory and coins to it in one click.

![Mothership Primary](docs/mothership-primary.png)

### Mothership — Support Vessel

Support vessel accounts show which mothership they belong to and expose transfer buttons.

![Mothership Support Vessel](docs/mothership-support.png)

### Commands

Toggle any of the command loops on or off live. Changes take effect on the next cycle, no restart needed.

![Commands](docs/commands.png)

### Balance & Net Worth Tracker

Wallet, bank, and net worth polled every 30 seconds with full historical charts per account.

![Balance and Net Worth](docs/balance.png)

### Stealth Settings

Four anti-detection presets. Casual mode shown: 40% typing chance, 100–300ms delay, +0–10% cooldown variance. Uptime/Downtime cycle configured to 30min active / 10min rest.

![Stealth Settings](docs/stealth.png)

### Market Sniper

Scans `pls market view` on a configurable interval and auto-buys coin listings under your max price per item. Live buy history with per-item totals.

![Market Sniper](docs/market-sniper.png)

### Fishing Mode

Exclusive fishing loop, pauses all other commands and the balance tracker while active. Live stats: catches per species, bucket sells, and session time with a chart.

![Fishing](docs/fishing.png)

### Adventure

Select adventure type from a dropdown. Cooldown is calculated automatically after each run based on interaction count, with a 60-second safety buffer. Custom answers let you pick your own responses for each prompt.

![Adventure](docs/adventure.png)

### Risk Mode — Custom Search Order

Set the search risk to Custom and drag locations into your preferred priority order. The bot works down the list from top to bottom.

![Risk Mode Custom Search](docs/risk-mode-search.png)

### Risk Mode — Custom Crime Order

Same drag-to-reorder system for crime. Each preset (Low, Medium, High) maps to a fixed set of safe responses; Custom lets you define your own.

![Risk Mode Custom Crime](docs/risk-mode-crime.png)

### Cooldowns & Timing

All timing values in one place. Auto-saved on change, hot-reloaded into the bot within 5 seconds.

![Cooldowns](docs/cooldowns.png)

### Activity Log

Live feed of every bot action, commands sent, responses received, button clicks, sniper events, stealth delays, warnings, and errors.

![Activity Log](docs/activity-log.png)

## License

MIT License. See [LICENSE](LICENSE) for the full text.
