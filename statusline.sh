#!/bin/bash

# Claude Code status line: reads session JSON on stdin, prints two lines.
# Field reference: https://code.claude.com/docs/en/statusline#available-data

export LC_NUMERIC=C

input=$(cat)

# One jq pass. \x1f (non-whitespace) keeps empty optional fields in place for `read`.
fields=$(echo "$input" | jq -r '[
    .model.display_name,
    (.effort.level // ""),
    .workspace.current_dir,
    (.context_window.used_percentage // 0),
    (.context_window.total_input_tokens // 0),
    .context_window.context_window_size,
    (.cost.total_cost_usd // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
] | map(tostring) | join("\u001f")') || exit 1

IFS=$'\x1f' read -r model effort current_dir ctx_pct ctx_tokens ctx_size cost \
    lines_added lines_removed five_pct five_reset week_pct week_reset <<<"$fields"

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
GRAY=$'\033[90m'
# Reset foreground only: a full reset (0m) would also drop the dim style
# Claude Code applies to status line text
RESET=$'\033[39m'

color_for_pct() {
    if [ "$1" -ge 80 ]; then
        printf '%s' "$RED"
    elif [ "$1" -ge 50 ]; then
        printf '%s' "$YELLOW"
    else
        printf '%s' "$GREEN"
    fi
}

format_tokens() {
    if [ "$1" -ge 1000000 ] && [ $(($1 % 1000000)) -eq 0 ]; then
        printf '%dM' $(($1 / 1000000))
    else
        printf '%dK' $(($1 / 1000))
    fi
}

# Time left until an epoch timestamp: "6d 12h", "3h 45m" or "12m"
format_remaining() {
    local left=$(($1 - $(date +%s)))
    if [ "$left" -lt 0 ]; then left=0; fi
    local d=$((left / 86400)) h=$((left % 86400 / 3600)) m=$((left % 3600 / 60))
    if [ "$d" -gt 0 ]; then
        printf '%dd %dh' "$d" "$h"
    elif [ "$h" -gt 0 ]; then
        printf '%dh %dm' "$h" "$m"
    else
        printf '%dm' "$m"
    fi
}

# --- Line 1: model, directory, git, code changes ---

model_info="$model"
if [ -n "$effort" ]; then
    model_info="$model · $effort"
fi

git_info=""
branch=$(git --no-optional-locks -C "$current_dir" branch --show-current 2>/dev/null)
if [ -n "$branch" ]; then
    git_info="$branch"
    if counts=$(git --no-optional-locks -C "$current_dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null); then
        read -r behind ahead <<<"$counts"
        if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
            git_info="$git_info ✓"
        elif [ "$behind" -eq 0 ]; then
            git_info="$git_info ↑$ahead"
        elif [ "$ahead" -eq 0 ]; then
            git_info="$git_info ↓$behind"
        else
            git_info="$git_info ↑$ahead ↓$behind"
        fi
    fi
fi

# Icons (Nerd Fonts): 󱐋 model, 󰉋 folder, 󰊢 git, 󰓅 context, 󰮯 cost
line1=("󱐋 $model_info" "󰉋 $(basename "$current_dir")")
if [ -n "$git_info" ]; then
    line1+=("󰊢 $git_info")
fi
if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
    line1+=("${GREEN}+$lines_added${RESET}/${RED}-$lines_removed${RESET}")
fi

# --- Line 2: context, subscription limits, cost ---

pct=${ctx_pct%.*}
filled=$((pct / 10))
bar=""
for ((i = 0; i < 10; i++)); do
    if [ "$i" -lt "$filled" ]; then bar+="█"; else bar+="░"; fi
done
context_info="$(color_for_pct "$pct")$bar ${pct}%${RESET} ($(format_tokens "$ctx_tokens")/$(format_tokens "$ctx_size"))"

line2=("󰓅 $context_info")

# rate_limits is only sent to Pro/Max subscribers, after the first API response
if [ -n "$five_pct" ]; then
    p=$(printf '%.0f' "$five_pct")
    line2+=("5h $(color_for_pct "$p")${p}%${RESET} ${GRAY}($(format_remaining "${five_reset%.*}"))${RESET}")
fi
if [ -n "$week_pct" ]; then
    p=$(printf '%.0f' "$week_pct")
    line2+=("7d $(color_for_pct "$p")${p}%${RESET} ${GRAY}($(format_remaining "${week_reset%.*}"))${RESET}")
fi

line2+=("󰮯 \$$(printf '%.2f' "$cost")")

print_line() {
    local out=$1
    shift
    for part in "$@"; do
        out+=" | $part"
    done
    printf '%s\n' "$out"
}

print_line "${line1[@]}"
print_line "${line2[@]}"
