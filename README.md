# omacodex

A native Omarchy shell bar plugin for ChatGPT Codex subscription usage.

The bar displays the ChatGPT knot. Clicking it opens a panel with the Codex
logo and title, Session and Weekly usage bars, additional reported quota
buckets (such as Code Review when available), credits, earned resets, a seven-day
token chart, the last successful update time and a header Sync button.

## Requirements

- Omarchy's Quickshell shell with `qs.Ui` and `qs.Commons` (the September 2026
  plugin interface; this is not a Waybar module).
- Python 3, without third-party packages.
- Codex CLI on the shell's `PATH`, signed in through `codex login` with a
  ChatGPT account. API-key-only accounts do not expose subscription quotas.

## Install

```bash
omarchy plugin add https://github.com/jameswylde/omacodex.git --enable
```

Omarchy clones the repository, validates the plugin and installs it in
`~/.config/omarchy/plugins/omacodex.usage`. Follow the prompts to confirm
installation and choose its bar section; `--enable` enables it immediately.

To update:

```bash
omarchy plugin update omacodex.usage
```

## Use

- Click the ChatGPT icon to toggle the panel.
- Click the **refresh icon at the top right**, middle-click the bar icon, or press **R**, **Enter** or
  **Space** while the panel is focused to refresh.
- **Escape** or clicking outside closes the panel. Arrow keys scroll.
- The footer stays visible when extra quota buckets require scrolling.
- Sync runs every five minutes and when opening a panel older than one
  minute. The widget's Omarchy settings expose `refreshIntervalSec` (60–3600).
- Bars show **percentage remaining**, with the percentage on the left and the reset date on the right (`DD/MM/YYYY HH:mm`, desktop local timezone).

The panel uses Omarchy's own `Panel`, `KeyboardPanel`, `BarIconButton`,
`PanelHero`, `Button`, spacing, font and colour tokens, including live theme
changes. It supports horizontal and vertical bars.

Styling follows Wypr: a compact header and plan pill, icon-only sync action,
tinted logo tile, subtle bordered statistics and a muted update footer.

### Token history

The chart fetches all historical daily totals returned by ChatGPT and displays
seven calendar days at a time. It initially ends on the latest reported date;
the displayed date range identifies the selected historical week. Use the
arrows to browse older/newer weeks, **Today** for the current seven days, and
**Latest** to return to the latest reported week. Hover a bar for its exact
token count and date. Lifetime and peak-day totals appear beneath the chart.

Missing days are marked with a dash, not counted as zero. A returned zero is
displayed as zero. Chart totals sum only the reported days. Dates retain the server's
calendar-day labels; reset timestamps use the desktop's timezone.

History is fetched from `account/usage/read`; there are no historical-range or
pagination parameters in the installed protocol. The chart can browse every
daily bucket the service supplies, but cannot backfill dates the service omits.
History remains in memory and is refreshed with quotas. If history fails to
load, quota values still work and the chart shows an error.

## Data and authentication

`usage.py` launches `codex app-server`, initializes its JSON-RPC connection,
and calls only `account/read`, `account/rateLimits/read` and `account/usage/read`. Codex manages
authentication, including its configured credential storage and `CODEX_HOME`.
There is no separate API key, browser-cookie extraction, inference request,
or paid credit redemption. Each installation shows its signed-in account.

The helper does not read or print auth tokens, email addresses or account
IDs. It does not persist usage. The UI keeps its latest snapshot in memory;
on a failed sync it clears quota figures and shows an error while retaining
the last successful update time. Requests have bounded timeouts and the
temporary app server is stopped after each probe.

### Missing values and model limits

The service decides which buckets it exposes. Missing Session, Weekly or
credit values are marked as unavailable, never an invented zero. Some accounts
report only a shared weekly quota, with no separate session window. The widget
uses each window's duration, rather than assuming the primary window is Session.
A Code Review bar appears only if Codex returns that bucket; there is no empty
placeholder. Spark quotas are excluded. The widget does not infer limits from
local session token totals.

Other returned buckets are handled dynamically, including model-specific
session/weekly windows and individual spending limits. Shared and per-model
allowances are not added together. Credit balances are displayed as credits,
not converted into money. Earned resets are shown separately and cannot be
redeemed by this plugin.

OpenAI's documentation says weekly limits may apply to the shared plan
allowance and Spark has a separate allowance. It does not establish a
separate Astra-only weekly cap. The account's live response is the source
for displayed limits.

- [Codex app-server protocol](https://learn.chatgpt.com/docs/app-server)
- [Usage limits and pricing](https://learn.chatgpt.com/docs/pricing)

## Validate and troubleshoot

```bash
cd ~/.config/omarchy/plugins/omacodex.usage
omarchy plugin validate .
python3 -m unittest discover -s tests -v
node tests/test_chart.cjs # Optional developer check; Node is not required by the plugin.
python3 usage.py
```

If no usage loads, run `codex login` in a terminal, check the network and
confirm `codex` is on Omarchy's PATH. The app-server protocol can evolve;
this version was checked against the installed Codex schema and a live
ChatGPT login on 15 September 2026.

To disable:

```bash
omarchy plugin disable omacodex.usage
```

To uninstall:

```bash
omarchy plugin remove omacodex.usage
```

## Licence

Project code is MIT licensed. See `THIRD_PARTY_NOTICES.md` for icon sources.
OpenAI, ChatGPT and Codex marks belong to OpenAI; this is an independent plugin.
