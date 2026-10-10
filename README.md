# claude-code-statusline
claude code statusline setup

## Preview
<img width="1610" height="52" alt="image" src="https://github.com/user-attachments/assets/9a9ce2f4-9b88-4079-b4b4-1163068c43a1" />

```
󱐋 Opus 5.5 · high | 󰉋 statusline | 󰊢 master ✓ | +156/-23
󰓅 ███░░░░░░░ 32% (64K/200K) | 5h 23% (3h 45m) | 7d 41% (6d 12h) | 󰮯 $1.23
```

## Segments

| Segment | Source field | Notes |
| - | - | - |
| Model · effort | `model.display_name`, `effort.level` | Effort is hidden when the model doesn't support it |
| Directory | `workspace.current_dir` | |
| Git | local `git` | Branch plus `✓` / `↑ahead` / `↓behind` / `↑ahead ↓behind` against upstream |
| Code changes | `cost.total_lines_added`, `cost.total_lines_removed` | Hidden while both are 0 |
| Context | `context_window.used_percentage`, `total_input_tokens`, `context_window_size` | |
| 5h / 7d limits | `rate_limits.five_hour`, `rate_limits.seven_day` | Pro/Max only, after the first response; dimmed `(3h 45m)` is the time left until reset |
| Cost | `cost.total_cost_usd` | Same figure as `/usage` → Session "Total cost": a list-price estimate, not your bill |

Context and limit percentages are green below 50%, yellow below 80%, red from 80%.

## Requirements

- [jq](https://jqlang.github.io/jq/)
- A [Nerd Font](https://www.nerdfonts.com/) in your terminal (e.g. JetBrainsMono Nerd Font)

## Install

```bash
git clone https://github.com/JoJoJotarou/claude-code-statusline.git
cd claude-code-statusline
./setup-statusline.sh
```

This copies `statusline.sh` to `~/.claude/statusline-command.sh` and adds `statusLine` (with `refreshInterval: 60` so the reset countdown keeps ticking while idle) to `~/.claude/settings.json` if it isn't set. Re-run it to upgrade.

Try it with mock input:

```bash
echo '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$PWD"'"},"context_window":{"used_percentage":25,"total_input_tokens":50000,"context_window_size":200000},"cost":{"total_cost_usd":0.42}}' | ./statusline.sh
```

## Uninstall

```bash
./uninstall-statusline.sh
```
