#!/bin/bash

# Claude Code 状态栏一键配置脚本
# 功能：自动安装和配置精美的状态栏显示

set -e

echo "🚀 Claude Code 状态栏配置脚本"
echo "================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 创建 .claude 目录（如果不存在）
CLAUDE_DIR="$HOME/.claude"
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "📁 创建 .claude 目录..."
    mkdir -p "$CLAUDE_DIR"
fi

# 2. 创建状态栏脚本
STATUSLINE_SCRIPT="$CLAUDE_DIR/statusline-command.sh"
echo "📝 创建状态栏脚本..."

cat > "$STATUSLINE_SCRIPT" << 'SCRIPT_EOF'
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

# Calculate session spending
# Pricing based on Claude 3.5 Sonnet (per million tokens)
# Input: $3/MTok, Output: $15/MTok
input_cost=$(echo "scale=4; $session_input * 3 / 1000000" | bc)
output_cost=$(echo "scale=4; $session_output * 15 / 1000000" | bc)
cost=$(echo "scale=4; $input_cost + $output_cost" | bc)

# Format cost with leading zero
if [[ "$cost" == .* ]]; then
    cost="0$cost"
fi

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
SCRIPT_EOF

# 3. 设置可执行权限
echo "🔒 设置可执行权限..."
chmod +x "$STATUSLINE_SCRIPT"

# 4. 更新 settings.json
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
echo "⚙️  更新 Claude Code 配置..."

if [ ! -f "$SETTINGS_FILE" ]; then
    # 创建新的 settings.json
    cat > "$SETTINGS_FILE" << 'JSON_EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
JSON_EOF
    echo -e "${GREEN}✓${NC} 已创建新的 settings.json"
else
    # 检查是否已有 statusLine 配置
    if grep -q '"statusLine"' "$SETTINGS_FILE"; then
        echo -e "${YELLOW}⚠${NC}  settings.json 中已存在 statusLine 配置"
        echo "   将保留现有配置（如需更新请手动修改）"
    else
        # 使用 jq 添加 statusLine 配置
        if command -v jq &> /dev/null; then
            TMP_FILE=$(mktemp)
            jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline-command.sh"}}' "$SETTINGS_FILE" > "$TMP_FILE"
            mv "$TMP_FILE" "$SETTINGS_FILE"
            echo -e "${GREEN}✓${NC} 已更新现有 settings.json"
        else
            echo -e "${YELLOW}⚠${NC}  未安装 jq，请手动添加以下配置到 $SETTINGS_FILE："
            echo ""
            echo '  "statusLine": {'
            echo '    "type": "command",'
            echo '    "command": "~/.claude/statusline-command.sh"'
            echo '  }'
        fi
    fi
fi

# 5. 测试图标显示
echo ""
echo "🎨 测试 Nerd Fonts 图标显示："
echo "   󱐋 AI模型 | 󰉋 目录 | 󰊢 Git | 󰓅 仪表盘 | 󰔵 求和 | 󰮯 现金"
echo ""

# 6. 完成提示
echo "================================"
echo -e "${GREEN}✨ 状态栏配置完成！${NC}"
echo ""
echo "📋 配置文件位置："
echo "   脚本: $STATUSLINE_SCRIPT"
echo "   配置: $SETTINGS_FILE"
echo ""
echo "🎯 状态栏将显示："
echo "   • 󱐋 模型名称"
echo "   • 󰉋 当前目录"
echo "   • 󰊢 Git 分支和同步状态"
echo "   • 󰓅 上下文使用率（带进度条）"
echo "   • 󰔵 Tokens 消耗"
echo "   • 󰮯 会话花费"
echo ""
echo "🔄 请重启 Claude Code 查看效果！"
echo ""
echo "💡 提示："
echo "   - 确保终端使用 Nerd Fonts（如 JetBrainsMono Nerd Font）"
echo "   - 如果图标显示为方块，请安装 Nerd Fonts 字体"
echo ""
