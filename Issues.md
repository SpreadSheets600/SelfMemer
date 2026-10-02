# SelfMemer — Codebase Audit: Issues Found

Static audit of the current sources (`main.js`, `bal_tracker.js`, `manager.js`, `server.py`, `web/*`, configs). No runtime execution performed. Line numbers are approximate.

Severity: 🔴 critical · 🟠 high · 🟡 medium · 🔵 minor

---

## 1. Correctness bugs

### 🔴 1.1 Market-sniper buys are double-counted
`main.js` logs `[SNIPER:BUY] <name> <price> <qty>` **and** POSTs `/api/accounts/<id>/sniper-event` for the same purchase (main.js ~2254, ~2255/2265). `server.py` appends a buy in **both** paths: `_update_sniper_from_log()` (server.py:93-118) and the `sniper_event` route (server.py:388-404). Result: every buy appears twice in "recent buys" and in `total_buys` / `total_coins_spent`.

### 🔴 1.2 Debug "market study" probe runs on every startup — and clicks a button
`studyMarketView()` (main.js:2285) is in the `Promise.all(...)` startup list (main.js:2940). It no-ops only if `_cfg.market_study_item` is empty — but `config.json` ships `"market_study_item": "apple"`, so every bot boot sends `pls market view apple`, dumps the entire component tree to the log, and **clicks the first non-disabled "Buy-like" button (or the first non-disabled button at all)** (main.js:2375-2392). A leftover debug feature that can trigger real market interactions and spams the activity log.

### 🔴 1.3 Adventure custom responses can never be saved
`server.py` `update_account()` (server.py:207-256) handles every config key except `adv_response_mode` and `adv_custom_responses`. The dashboard PUTs both when the user picks custom mode or edits a choice (scripts.js:1675, 1710), but the server silently drops them and returns `{ok: true}`. So the whole "Custom answers" adventure feature looks saved in the UI but never persists to `config.json`; `main.js` hot-reload (main.js:118-121) will never see it.

### 🔴 1.4 Six cooldown settings edited in the UI are silently discarded
`NUMERIC_FIELDS` in server.py (lines 14-18) omit `daily_cooldown`, `work_cooldown`, `deposit_cooldown`, `trivia_cooldown`, `stream_cooldown`, `pet_cooldown`. The dashboard exposes all six as `data-config` inputs (index.html), and `collectNumeric()` sends them — but the PUT handler ignores any key not in `NUMERIC_FIELDS`. The UI shows the new value (scripts.js merges the payload into the local cache, line 911), yet nothing is written to disk and a page reload reverts it.

### 🟠 1.5 `hl_wait_for` is completely dead
It's in `NUMERIC_FIELDS` and in the README, but `main.js` never loads it into `_cfg` (the hot-reload key list, main.js:89-97, lacks it) and `hlLoop` uses `_cfg.wait_for_response` instead (main.js:1563). The setting does nothing anywhere.

### 🟠 1.6 CAPTCHA pause is auto-undone after ~5 seconds
The CAPTCHA handler calls `setPaused(true)` (main.js:2769), but `cycleLoop()`'s idle branch unconditionally resets `_botPaused` when `limit_flags` is off or the cycle is disabled (main.js:1422-1425). Net effect: a CAPTCHA pause lasts one 5 s tick unless a full uptime/downtime cycle is configured — the bot resumes while the CAPTCHA is unsolved.

### 🟠 1.7 Sniper and mothership loops ignore the uptime/downtime pause
`fishLoop`, all command loops, and `bal_tracker` check `_botPaused`; `marketSniperLoop()` (main.js:2156) and `mothershipMarketLoop()` (main.js:1338) do not. During a configured "rest" window the account still scans/buys on the market and accepts mothership offers — the anti-detection cycling is leaky.

### 🟠 1.8 Transfer "friends share" / "market post" strip spaces out of item names
`parseInventoryItems()` builds `name = noEmoji.replace(/\s+/g, '')` (main.js:1039), then uses that stripped name in shell-style commands: `pls friends share items <@uid> q Superfish` (main.js:1173) and `pls market post ... sell q Superfish` (main.js:1066). Dank Memer item names are multi-word ("Super Fish", "Hunting Rifle"); the stripped form won't match. `IGNORED_ITEMS` happens to match because it's also space-stripped, which masks the bug in config but breaks the actual transfer commands.

### 🟠 1.9 `PUT /api/accounts/<id>` returns success when the account doesn't exist
The mutation loop only runs on match, but `save_config(cfg)` + `{ok: true}` run regardless (server.py:255-256). Same pattern in `save_market_sniper` (server.py:372-373) and `set_discord_uid` (server.py:467-468). Typos in `account_id` silently "succeed".

### 🟠 1.10 One transient error kills each command loop forever
The bodies of `huntLoop`, `digLoop`, `searchLoop`, `begLoop`, `crimeLoop`, `hlLoop`, `pmLoop`, `advLoop`, `dailyLoop`, `workLoop`, `depositLoop`, `triviaLoop`, `streamLoop`, `petLoop`, `fishLoop`, `marketSniperLoop`, and `mothershipMarketLoop` have no per-iteration `try/catch`. If `channel.send`, a button click, or a fetch throws (Discord hiccup, timeout), the loop's promise rejects, its `while(true)` ends, and that feature is dead for the rest of the process lifetime. The process stays "alive": `heartbeatLoop` keeps logging, `/api/status` reports the account online, and `manager.js` only restarts on process exit — so nobody is notified. The `Promise.all(...).catch` at the bottom logs `Fatal:`, but it is not fatal — the other loops keep running.

### 🟠 1.11 Stale `interaction_lock_*.lock` is never cleaned up
`Mutex.runExclusive()` deletes the lock file in a `finally` (main.js:141-150), but `main.js` installs no `SIGTERM`/`SIGINT` handler, so a manager restart or kill leaves the file behind. `bal_tracker.js`'s `waitForMainLock()` (bal_tracker.js:216-222) then waits for the file to disappear before every `pls bal`, starving the tracker until `main.js` happens to run and finish one exclusive section. Startup clears the paused flag (main.js:804) but not the lock file.

### 🟡 1.12 Fishing exclusive mode destroys previous toggle state
Toggling fishing ON disables every other command *and* the balance tracker (`commands_enabled: {…, all false}`, `bal_tracker_enabled: false`, scripts.js:1441-1453). Toggling fishing OFF only sets `fish: false` (scripts.js:1454-1460) — the previously enabled commands and the balance tracker are **not** restored; the user has to re-enable everything by hand.

### 🟡 1.13 Dynamic `Referer` override probably never takes effect
`client.options.http.headers['Referer'] = exactReferer` (main.js:821) mutates the options object after the REST client has been constructed; discord.js builds its request headers from the options captured at init. The "dynamic Referer" is therefore most likely a no-op in practice.

### 🟡 1.14 Adventure custom-mode key mismatch risk
`pickAdventureChoice()` looks up custom overrides by `rule.keywords[0]` (main.js:743-746); the dashboard keys them by `ADV_PROMPTS[...].id` (scripts.js:1670). They currently line up by hand-maintenance; any future reorder/typo in either file silently falls back to the recommended answer.

### 🟡 1.15 Fish/sniper "session" timestamps never reset
`_fish_stats` / `_sniper_stats` are keyed forever by account and `session_start` is set once at server start (server.py:90-91, 120-121). Toggle fishing on/off several times in a week and "session time" keeps counting from the first boot. Only the explicit Reset buttons fix it.

### 🟡 1.16 `main.js` has no login failure handling
`client.login(TOKEN)` (main.js:2944) and `bal_tracker.js` have no `.catch`/retry. A bad token or network error → unhandled rejection/crash → `manager.js` restarts every 5 s forever, with no useful dashboard-visible error.

### 🔵 1.17 `bal_tracker` drops a late balance reply
On the 15 s timeout, `waitingForBal` and `sentBalMsgId` are reset (bal_tracker.js:244-250), and the listener requires a non-null `sentBalMsgId` (bal_tracker.js:280) — a reply arriving after the timeout is discarded, so that sample is lost and the timeline has a silent gap.

### 🔵 1.18 Heatmap-jitter direction contradicts the README
`humanJitter()` (main.js:386-392) only ever *adds* 0..+variance% to the cooldown; the README advertises "±35%". One-sided extension of every cooldown also slightly lowers the effective action rate vs. configured.

---

## 2. State storage & persistence

### 🔴 2.1 `config.json` has no `.gitignore` and IS tracked by git
The repo contains **no** `.gitignore`, and `git ls-files` shows `config.json` committed (with placeholder token today). The README (lines 229, 308) claims the opposite. Anyone following the setup puts their live Discord token in git history on the first real save. Also unprotected: `balance_*.json`, `interaction_lock_*`, `paused_*.flag`, `transfer_trigger_*.json`, `transfer_status_*.json`, `market_pending_*.json`.

### 🟠 2.2 Concurrent config writes can clobber each other
`load_config()`/`save_config()` each take the lock, but the read-modify-write sequence in `update_account`, `set_mothership`, `toggle_bal_tracker`, `set_discord_uid`, `trigger_transfer`, `save_market_sniper` runs **outside** any lock (server.py). Two near-simultaneous dashboard edits (e.g., a toggle plus a cooldown change) can overwrite one of them.

### 🟠 2.3 All JSON state files are written non-atomically
`save_config` (server.py:63-66), `saveHistory` (bal_tracker.js:35-38), `writeTransferStatus` (main.js:1022-1026), the pending-offer files, and the trigger files all use plain `writeFileSync`/`json.dump`. A crash or SIGKILL mid-write corrupts the file; a reader on another process can observe a torn document (JSON.parse throws → `load_config()` 500s everywhere, `manager.js` treats config as `[]` and kills every account, `bal_tracker` resets its history). No temp-file-then-rename anywhere.

### 🟠 2.4 Fish stats, sniper stats, logs, and online-status live only in memory
`_fish_stats`, `_sniper_stats`, `_log_buffer`, `_heartbeat` (server.py:78-88) die with the Flask process. After a server restart the dashboard shows zeroed fish/sniper sessions and an empty activity log even though the bots kept running. Only balance history is on disk.

### 🟡 2.5 Uptime/downtime cycle phase resets on restart
`cycleLoop()` restarts its timing from "uptime" on every boot (main.js:1416-1460); a bot interrupted mid-downtime comes back up immediately. No persistence of the cycle phase.

### 🟡 2.6 Orphaned runtime files
`delete_account` (server.py:197-205) removes the balance file but leaves `paused_<id>.flag`, `interaction_lock_<id>.lock`, `transfer_trigger_<id>.json`, `transfer_status_<id>.json`, `market_pending[_coins]_<id>.json` behind, and leaves `mothership_id` dangling if the deleted account was the mothership (transfers then fail with "Mothership Discord UID not available yet"-style errors).

---

## 3. Concurrency / locking

### 🟠 3.1 `fishLoop` bypasses the `disable_interaction_lock` toggle
It takes `_interactionLock.runExclusive(...)` directly (main.js:1856) instead of `runWithLock(...)` (main.js:217-220) used by every other loop. Users who enable "parallel mode" for premium servers still get fully serialized (and lock-file-blocking) fishing sessions.

### 🟠 3.2 The file-based lock is advisory and one-directional
The `interaction_lock_*.lock` file is only **checked** by `bal_tracker` (bal_tracker.js); nothing in the mothership side or the dashboard coordinates. Combined with 1.11, the lock's semantics are "usually blocks the tracker" rather than a real mutex.

### 🟡 3.3 `client.on('messageCreate')` helpers run outside the mutex
The CAPTCHA/alert/autobuy/minigame handler (main.js:2761-2929) clicks buttons and sends `pls alert` without `runWithLock`, so it can interleave with an in-flight command response and steal/confuse `_pendingReplies`.

---

## 4. UI / dashboard issues

### 🟠 4.1 Silently-discarded settings (see 1.3, 1.4, 1.5)
The UI offers controls that do nothing: adventure custom responses (1.3), six cooldown fields (1.4), `hl_wait_for` (1.5 — not even shown). Because the server returns `ok` and the UI optimistically merges the payload into its local cache, users believe the change persisted.

### 🟡 4.2 Fishing toggle is destructive (see 1.12)

### 🟡 4.3 `adv_cooldown` is not editable from the dashboard
`adv_cooldown` is in `NUMERIC_FIELDS`, defaults in `DEFAULT_ACCOUNT`, and used by `advLoop`, but there is no `data-config` input for it in `index.html` and no entry in the cooldown edit DEFAULTS in `scripts.js` — only the config file can change it.

### 🔵 4.4 Chart.js loaded from CDN
`index.html:8` pulls Chart.js from jsDelivr with no local fallback/SRI — the dashboard's charts (and overview pies) break entirely when offline.

### 🔵 4.5 Typos/leftovers
`applySteathMode` (scripts.js:383) is a typo propagated through all call sites; harmless but confusing. `stealthExtraSleep()` (main.js:414) is a dead stub kept "for backward compat".

---

## 5. Security

### 🟠 5.1 No `.gitignore` + token in tracked `config.json` (see 2.1)

### 🟡 5.2 API has no authentication and binds `0.0.0.0`
Anyone on the LAN (or the internet if the port is forwarded) can read every account token via `GET /api/accounts`, edit configs, trigger transfers, and forge sniper events. README acknowledges this (line 313) but there's nothing in code to enforce even a shared-secret header.

### 🔵 5.3 Flask dev server in production
`app.run(...)` (server.py:547) is single-threaded+debug=False; fine for localhost, but combined with the non-atomic writes, a dropped connection or Flask error leaves torn state possible.

---

## 6. Performance / polish

### 🟡 6.1 Charts are rebuilt, not updated
`fetchBalance()` destroys and recreates the Chart.js instances on every 30 s poll (scripts.js:303, 318); same for the overview pies (scripts.js:2163, 2184) and the fish chart dataset shuffle. With 2 000-point histories this allocates a lot of canvas work per tick.

### 🟡 6.2 Full-history rewrite every 30 s
`saveHistory()` (bal_tracker.js:35-38) serializes up to 2 000 entries to disk on every balance poll, and `/api/overview` re-reads and re-parses every account's file on every 30 s dashboard tick (server.py:520-544).

### 🔵 6.3 Startup study probe spam (see 1.2)
Also: `configReloadLoop` re-reads and diffs the whole config every 5 s per account, and `manager.js` re-reads it every 2 s — acceptable, but `market_study_item` not being hot-reloaded means changing it never takes effect without a restart.

---

## 7. Cleanup / hygiene

- `package.json`: name `workspace`, `main: index.js` (nonexistent), no `start` script, `"test"` stub.
- `pyproject.toml`: name `repl-nix-workspace`, placeholder description.
- `main.js` trivia DB parses the 1.6 MB `trivia.json` at every account boot — acceptable, but only needed when trivia is enabled.
- `bal_tracker` duplicates `resolveChannel` from `main.js` (near-identical ~40 lines); the two `Mutex` and `extractText` helpers are also duplicated across files.
- Stray debug/`[STUDY]` machinery shipped in the hot path (1.2).
- README architecture note says manager watches config "every 5s"; code is 2 s.

---

*Audit method: full static read of every source file; no code was executed. Grouped by category; severities are judgement calls, not measurements.*

---

## Resolution status (this pass)

| # | Issue | Status | Fix |
|---|-------|--------|-----|
| 1.1  | Sniper buys double-counted | ✅ Fixed | Removed log-parsed double-append in `server.py`; endpoint is the single source of truth |
| 1.2  | Study probe runs on boot & clicks | ✅ Fixed | Gated behind `SELFMEMER_MARKET_STUDY`; never runs in normal operation |
| 1.3  | Adventure custom responses dropped | ✅ Fixed | `update_account` now accepts & validates `adv_response_mode` / `adv_custom_responses` |
| 1.4  | Six cooldowns dropped by server | ✅ Fixed | All six added to `NUMERIC_FIELDS` (+ `DEFAULT_ACCOUNT`) |
| 1.5  | `hl_wait_for` dead | ✅ Fixed | Wired into `_cfg`, hot-reload, and `hlLoop` |
| 1.6  | CAPTCHA pause auto-undone | ✅ Fixed | Cycle loop no longer clears CAPTCHA pause; explicit Resume button added |
| 1.7  | Sniper/mothership ignore pause | ✅ Fixed | Both loops check `_botPaused` |
| 1.8  | Transfer item names despaced | ✅ Fixed | Names keep spaces; ignore-matching uses a stripped projection |
| 1.9  | `PUT` ok-for-missing account | ✅ Fixed | Returns 404 (also for sniper-config POST, discord_uid, mothership POST) |
| 1.10 | One error kills a loop | ✅ Fixed | Every loop wrapped in a supervisor that restarts it in 5 s |
| 1.11 | Stale lock file | ✅ Fixed | Cleared at startup + SIGTERM/SIGINT handlers remove it |
| 1.12 | Fishing toggle destructive | ✅ Fixed | Previous toggles + bal-tracker state restored on fish-off |
| 1.13 | Referer override ineffective | ✅ Fixed (best effort) | Also patched `client.rest.options.headers` |
| 1.14 | Custom adv key mismatch | ✅ Fixed | Substring-tolerant fallback lookup |
| 1.15 | Session timestamps never reset | ✅ Fixed | `SESSION_START` log markers reset `session_start` on toggle-on |
| 1.16 | No login failure handling | ✅ Fixed | `client.login(...).catch` logs clearly and exits; manager restarts with backoff |
| 1.17 | Late bal reply dropped | ✅ Fixed | 60 s grace window, late replies accepted |
| 1.18 | Jitter doc mismatch | ✅ Fixed | README documents one-sided jitter |
| 2.1  | No `.gitignore`, token tracked | ✅ Fixed | `.gitignore` added; `git rm --cached config.json` run |
| 2.2  | Config write races | ✅ Fixed | All config mutations now go through `modify_config()` under one lock |
| 2.3  | Non-atomic JSON writes | ✅ Fixed | tmp+rename everywhere (config, balance, trigger/status, stats) |
| 2.4  | Memory-only stats/logs | ✅ Fixed | Fish & sniper stats persist to disk; cycle state persisted; logs remain in-memory (documented) |
| 2.5  | Cycle phase reset | ✅ Fixed | `cycle_<id>.json` resume after restart |
| 2.6  | Orphaned files on delete | ✅ Fixed | `delete_account` removes all runtime artefacts + clears dangling mothership |
| 3.1  | fishLoop bypasses lock toggle | ✅ Fixed | Uses `runWithLock` |
| 3.3  | messageCreate helpers outside lock | ➖ Documented | Minigame/autobuy clicks still intentional (they *are* the response) |
| 4.3  | `adv_cooldown` not in UI | ✅ Fixed | Added to Adventure card |
| 4.4  | Chart.js CDN | ➖ Noted | Self-hosting Chart.js is a recommended next step |
| 6.x  | Perf (chart rebuilds, full history rewrites) | ➖ Noted | Tracker optimized; chart update-in-place is a future refactor |

Plus repository-level improvements: `npm start`, `make test`, `Makefile`, hardened `start.sh` (requirements check + PID cleanup), `package.json`/`pyproject.toml` metadata, supervisor loop for crash recovery, manager crash-backoff (60 s after 5 crashes in 90 s).
