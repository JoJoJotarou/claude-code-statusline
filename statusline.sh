#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

# Get current directory name (not full path)
dir_name=$(basename "$current_dir")

# Get context window usage percentage with progress bar
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    pct=$((current * 100 / size))

    # Create progress bar (10 characters wide)
    filled=$((pct / 10))
    empty=$((10 - filled))
    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    context_info="$bar ${pct}%"
else
    context_info="░░░░░░░░░░ 0%"
fi

# Get git branch and sync status
cd "$current_dir" 2>/dev/null || cd /
git_info=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        git_info="$branch"

        # Get sync status with remote
        upstream=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-parse --abbrev-ref @{upstream} 2>/dev/null)
        if [ -n "$upstream" ]; then
            local_commit=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-parse @ 2>/dev/null)
            remote_commit=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-parse @{upstream} 2>/dev/null)
            base_commit=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false merge-base @ @{upstream} 2>/dev/null)

            if [ "$local_commit" = "$remote_commit" ]; then
                sync_status="✓"
            elif [ "$local_commit" = "$base_commit" ]; then
                ahead=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-list --count @..@{upstream} 2>/dev/null)
                sync_status="↓$ahead"
            elif [ "$remote_commit" = "$base_commit" ]; then
                behind=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-list --count @{upstream}..@ 2>/dev/null)
                sync_status="↑$behind"
            else
                ahead=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-list --count @{upstream}..@ 2>/dev/null)
                behind=$(git -c core.useBuiltinFSMonitor=false -c gc.autodetach=false rev-list --count @..@{upstream} 2>/dev/null)
                sync_status="↕$ahead/$behind"
            fi
            git_info="$git_info $sync_status"
        fi
    fi
fi

# Calculate tokens usage (input + output in K)
session_input=$(echo "$input" | jq '.context_window.total_input_tokens')
session_output=$(echo "$input" | jq '.context_window.total_output_tokens')
total_tokens=$((session_input + session_output))
tokens_k=$((total_tokens / 1000))

# Session cost as computed by Claude Code (same figure as /usage "Total cost")
cost=$(printf '%.2f' "$(echo "$input" | jq '.cost.total_cost_usd // 0')")

# Format the status line with Nerd Fonts icons (方案A: 简洁现代)
# Icons: 󱐋 (lightning-bolt-outline), 󰉋 (folder), 󰊢 (git-branch), 󰓅 (gauge), 󰔵 (sigma), 󰮯 (cash)
status_parts=()
status_parts+=("󱐋 $model_name")      # AI模型
status_parts+=("󰉋 $dir_name")        # 目录
if [ -n "$git_info" ]; then
    status_parts+=("󰊢 $git_info")    # Git
fi
status_parts+=("󰓅 $context_info")    # 上下文
status_parts+=("󰔵 ${tokens_k}K")     # Tokens
status_parts+=("󰮯 \$$cost")          # 花费

# Join with ' | '
printf '%s' "${status_parts[0]}"
for ((i=1; i<${#status_parts[@]}; i++)); do
    printf ' | %s' "${status_parts[$i]}"
done
