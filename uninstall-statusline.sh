#!/bin/bash

# Claude Code 状态栏一键卸载脚本
# 功能：自动移除状态栏配置和相关文件

set -e

echo "🗑️  Claude Code 状态栏卸载脚本"
echo "================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 文件路径
CLAUDE_DIR="$HOME/.claude"
STATUSLINE_SCRIPT="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# 检查是否有配置需要卸载
has_config=false

if [ -f "$STATUSLINE_SCRIPT" ]; then
    has_config=true
fi

if [ -f "$SETTINGS_FILE" ] && grep -q '"statusLine"' "$SETTINGS_FILE"; then
    has_config=true
fi

if [ "$has_config" = false ]; then
    echo -e "${YELLOW}⚠${NC}  未发现状态栏配置，无需卸载"
    echo ""
    exit 0
fi

# 显示将要删除的内容
echo "📋 将要移除以下配置："
echo ""

if [ -f "$STATUSLINE_SCRIPT" ]; then
    echo "   • 状态栏脚本: $STATUSLINE_SCRIPT"
fi

if [ -f "$SETTINGS_FILE" ] && grep -q '"statusLine"' "$SETTINGS_FILE"; then
    echo "   • settings.json 中的 statusLine 配置"
fi

echo ""

# 确认提示
read -p "确认卸载？(y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}✗${NC} 已取消卸载"
    echo ""
    exit 0
fi

echo ""
echo "🔄 开始卸载..."
echo ""

# 1. 删除状态栏脚本
if [ -f "$STATUSLINE_SCRIPT" ]; then
    echo "📝 删除状态栏脚本..."
    rm "$STATUSLINE_SCRIPT"
    echo -e "${GREEN}✓${NC} 已删除 statusline-command.sh"
fi

# 2. 从 settings.json 中移除 statusLine 配置
if [ -f "$SETTINGS_FILE" ] && grep -q '"statusLine"' "$SETTINGS_FILE"; then
    echo "⚙️  更新 settings.json..."

    if command -v jq &> /dev/null; then
        # 使用 jq 移除 statusLine 字段
        TMP_FILE=$(mktemp)
        jq 'del(.statusLine)' "$SETTINGS_FILE" > "$TMP_FILE"
        mv "$TMP_FILE" "$SETTINGS_FILE"
        echo -e "${GREEN}✓${NC} 已从 settings.json 移除 statusLine 配置"
    else
        echo -e "${YELLOW}⚠${NC}  未安装 jq，请手动从 $SETTINGS_FILE 中删除 statusLine 配置"
        echo ""
        echo "   需要删除的配置："
        echo '   "statusLine": {'
        echo '     "command": "~/.claude/statusline-command.sh"'
        echo '   }'
    fi
fi

# 3. 检查 settings.json 是否为空对象
if [ -f "$SETTINGS_FILE" ]; then
    if command -v jq &> /dev/null; then
        content=$(jq -r 'keys | length' "$SETTINGS_FILE" 2>/dev/null || echo "0")
        if [ "$content" = "0" ]; then
            echo "📁 settings.json 已空，是否删除？(y/N) "
            read -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm "$SETTINGS_FILE"
                echo -e "${GREEN}✓${NC} 已删除空的 settings.json"
            fi
        fi
    fi
fi

# 4. 完成提示
echo ""
echo "================================"
echo -e "${GREEN}✨ 状态栏配置已卸载！${NC}"
echo ""
echo "🔄 请重启 Claude Code 使更改生效"
echo ""
echo "💡 提示："
echo "   - 卸载后状态栏将恢复为默认显示"
echo "   - 如需重新安装，运行: ./scripts/setup-statusline.sh"
echo ""
