# omacodex

A native Omarchy shell bar plugin for ChatGPT Codex subscription usage.

The bar displays the ChatGPT knot. Clicking it opens a panel with the Codex
logo and title, Session and Weekly usage bars, additional reported quota
buckets (such as Spark or Code Review), credits, earned resets, the last
successful update time and a Sync button.

## Requirements

- Omarchy's Quickshell shell with `qs.Ui` and `qs.Commons` (the September 2026
  plugin interface; this is not a Waybar module).
- Python 3, without third-party packages.
- Codex CLI on the shell's `PATH`, signed in through `codex login` with a
  ChatGPT account. API-key-only accounts do not expose subscription quotas.

## Install

```bash
cd ~/omacodex
bash install.sh
```

The installer validates the manifest, links this directory to
`~/.config/omarchy/plugins/omacodex.usage`, rescans plugins and enables Codex
in the right bar section. Keep this source directory in place. Existing
unrelated plugins are not overwritten. For other users, clone/copy the
project anywhere and run `bash install.sh` from there.

## Use

- Click the ChatGPT icon to toggle the panel.
- Click **Sync**, middle-click the bar icon, or press **R**, **Enter** or
  **Space** while the panel is focused to refresh.
- **Escape** or clicking outside closes the panel. Arrow keys scroll.
- The footer stays visible when extra quota buckets require scrolling.
- Sync runs every five minutes and when opening a panel older than one
  minute. The widget's Omarchy settings expose `refreshIntervalSec` (60–3600).
- Bars show **percentage used**. Reset times use the desktop's local timezone.

The panel uses Omarchy's own `Panel`, `KeyboardPanel`, `BarIconButton`,
`PanelHero`, `Button`, spacing, font and colour tokens, including live theme
changes. It supports horizontal and vertical bars.

## Data and authentication

`usage.py` launches `codex app-server`, initializes its JSON-RPC connection,
and calls only `account/read` and `account/rateLimits/read`. Codex manages
authentication, including its configured credential storage and `CODEX_HOME`.
There is no separate API key, browser-cookie extraction, inference request,
or paid credit redemption. Each installation shows its signed-in account.

The helper does not read or print auth tokens, email addresses or account
IDs. It does not persist usage. The UI keeps its latest snapshot in memory;
on a failed sync it clears quota figures and shows an error while retaining
the last successful update time. Requests have bounded timeouts and the
temporary app server is stopped after each probe.

### Missing values and model limits

The service decides which buckets it exposes. Missing Session, Weekly,
Code Review or credit values display **Not reported**, never an invented
zero. A separate Code Review bar is populated only if Codex returns that
bucket. The widget does not infer limits from local session token totals.

All returned buckets are handled dynamically, including model-specific
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
omarchy plugin validate .
python3 -m unittest discover -s tests -v
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

To remove the development link after disabling:

```bash
unlink ~/.config/omarchy/plugins/omacodex.usage
omarchy-shell shell rescanPlugins
```

## Licence

Project code is MIT licensed. See `THIRD_PARTY_NOTICES.md` for icon sources.
OpenAI, ChatGPT and Codex marks belong to OpenAI; this is an independent plugin.
