# zed-copy-file-ref

Copy file references from Zed editor with a keyboard shortcut.

Press `Ctrl+Alt+R` to copy the current file and line (or selection range) to your clipboard in this format:

```
@project/src/utils/handler.ts#L42
@project/src/utils/handler.ts#L42-58
```

Useful for pasting into Claude, ChatGPT, or code review conversations to reference specific code locations.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ramilamparo/zed-copy-file-ref/main/install.sh | bash
```

### Requirements

- [Zed editor](https://zed.dev)
- `jq` — for merging into existing Zed config files
- A clipboard tool: `wl-copy` (Wayland), `pbcopy` (macOS), `xclip`, or `xsel` (X11)

## How it works

The installer adds three things to your Zed config (`~/.config/zed/`):

| File | Purpose |
|---|---|
| `scripts/copy-file-ref.sh` | Formats the reference and copies to clipboard |
| `tasks.json` | Registers a background task (no terminal tab) |
| `keymap.json` | Binds `Ctrl+Alt+R` to the task |

If `tasks.json` or `keymap.json` already exist, the installer merges into them without overwriting your other settings.

## Uninstall

```bash
rm ~/.config/zed/scripts/copy-file-ref.sh
```

Then remove the `"Copy File Reference"` entry from `~/.config/zed/tasks.json` and the `ctrl-alt-r` binding from `~/.config/zed/keymap.json`.

## License

MIT
