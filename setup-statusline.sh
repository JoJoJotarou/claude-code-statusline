#!/bin/bash

# Claude Code 状态栏一键配置脚本
# 功能：自动安装和配置精美的状态栏显示

set -e

echo "🚀 Claude Code 状态栏配置脚本"
echo "================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

cp "$SCRIPT_DIR/statusline.sh" "$STATUSLINE_SCRIPT"

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
