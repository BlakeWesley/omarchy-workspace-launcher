# Workspace Launcher

An Omarchy shell service plugin that launches your startup apps and puts each
window on the right workspace of the right monitor. It runs once per Hyprland
session, so restarting the shell does not launch a second copy of everything.

## How it works

At login the plugin's service starts, waits for Hyprland, then:

1. Resolves each app's target: a workspace slot on a monitor, or a special
   workspace such as the scratchpad.
2. Adds a temporary window rule for the app on that target.
3. Launches the app (if it is not already running).
4. Moves any matching window that opens to the target.
5. Brings a numeric target workspace home to the monitor named in the config.
6. Disables the temporary rules.

Because the rules live only for the startup pass, an app you open later is not
pinned to that workspace.

## Current starter layout

| App | Target |
|-----|--------|
| Chrome | DP-1 workspace 1 |
| Chromium | DP-1 workspace 9 |
| Google Messages | DP-1 workspace 4 |
| WhatsApp | DP-1 workspace 4, beside Messages |
| Discord | DP-1 workspace 5 |
| Ghostty | scratchpad (hidden until `Super + S`) |
| Files | DP-2 workspace 1 |
| Notion | DP-2 workspace 5 |
| VS Code | DP-2 workspace 9 |
| T3 Code | DP-2 workspace 0 (slot 10) |

Omarchy labels the tenth workspace on each monitor `0`. Write it as `10` in
`layout.json`, because the slots run from 1 to 10.

## Configure

Edit `layout.json` beside this README:

```json
{
  "settleSeconds": 30,
  "apps": [
    {
      "name": "Chromium",
      "monitor": "DP-1",
      "workspace": 9,
      "command": "uwsm-app -- chromium",
      "class": "^(chromium)$"
    },
    {
      "name": "Ghostty",
      "workspace": "scratchpad",
      "command": "uwsm-app -- ghostty",
      "class": "^(com\\.mitchellh\\.ghostty)$"
    }
  ]
}
```

| Field | Meaning |
|-------|---------|
| `name` | Label used in the log and the dry-run plan. |
| `monitor` | Connector name (`DP-1`, `eDP-1`, `HDMI-A-1`) or `primary` / `secondary` by monitor order. Required for a numeric workspace, ignored for a special one. |
| `workspace` | Workspace slot from 1 to 10 on that monitor, or a special workspace name such as `scratchpad`. |
| `command` | Shell command used to start the app. Include `uwsm-app --` for desktop apps that are not wrapped by an `omarchy-launch-*` helper. |
| `class` | Regular expression matched against the window's class. |
| `title` | Optional regular expression matched against the window's title too. |

`settleSeconds` is how long to wait for windows to appear, from 2 to 120
(30 in the starter). The loop stops early once every app has a window.

Two apps on the same workspace are tiled by your current layout, so putting
Google Messages and WhatsApp on DP-1 workspace 4 gives you the two side by
side. List them in the order you want the windows created.

Find a window's class with:

```bash
hyprctl clients -j | jq -r '.[] | [.class, .title] | @tsv'
```

`omarchy-launch-browser` follows your default browser. If you change the
default, update that entry's `class` regex too (for example `^(firefox)$`), or
point `command` at the browser explicitly.

Each monitor has its own block of ten workspaces in Omarchy (DP-1 = 1-10,
DP-2 = 11-20). Write the slot you see in the bar; the plugin works out the
Hyprland ID and keeps the window on the right screen.

`scratchpad` is Omarchy's special workspace, toggled with `Super + S`. Ghostty
starts in it hidden; press `Super + S` to show it and again to hide it.

## Re-apply without logging out

```bash
omarchy-shell blake.workspace-launcher apply
```

This moves windows that are already open and launches only apps that have no
window yet. It is safe to run after editing `layout.json`.

Check the last result:

```bash
omarchy-shell blake.workspace-launcher status
```

## Files

- Log: `~/.local/state/omarchy/workspace-launcher.log`
- Last result: `~/.local/state/omarchy/workspace-launcher.result`
- Last applied session: `~/.local/state/omarchy/workspace-launcher.session`

`apply` starts the layout in its own session, so restarting the shell cannot
interrupt a run that is still placing windows. `status` reads the result file;
expect `running`, then `ok` or `partial`.

The session marker is what makes the plugin run once per Hyprland session. If
you want to force a fresh run in the current session, use the `apply` command
above rather than deleting the marker.

## Notes

- An app whose monitor is unplugged is skipped, not dumped onto another screen.
  Plug the monitor in and run `apply` to place it.
- Apps that are already running are moved to their target, never launched
  twice.
- Duplicate `class`/`title` matches are rejected: one app, one target.
- Commands run under `sh -c` as your user, with the shell's environment.
