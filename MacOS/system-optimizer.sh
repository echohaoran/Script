#!/bin/bash

# macOS系统优化脚本
# 功能：优化macOS系统性能和设置
# 使用方法：./system-optimizer.sh [选项]

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/system-optimizer-$(date +%Y%m%d_%H%M%S).log"

# 创建日志文件
touch "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "       macOS系统优化工具"
echo "======================================"
echo "开始时间: $(date)"
echo ""

# 显示帮助信息
show_help() {
    echo "macOS系统优化脚本使用说明:"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -a, --all           执行所有优化"
    echo "  -d, --dock          优化Dock设置"
    echo "  -f, --finder        优化Finder设置"
    echo "  -s, --security      增强安全设置"
    echo "  -p, --performance   性能优化"
    echo "  -c, --cleanup       系统清理"
    echo "  -u, --ui            UI界面优化"
    echo ""
    echo "示例:"
    echo "  $0 -a               # 执行所有优化"
    echo "  $0 -d -f            # 优化Dock和Finder"
    echo "  $0 -p -c            # 性能优化和系统清理"
}

# 解析命令行参数
parse_args() {
    local optimize_all=false
    local optimize_dock=false
    local optimize_finder=false
    local optimize_security=false
    local optimize_performance=false
    local optimize_cleanup=false
    local optimize_ui=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                optimize_all=true
                shift
                ;;
            -d|--dock)
                optimize_dock=true
                shift
                ;;
            -f|--finder)
                optimize_finder=true
                shift
                ;;
            -s|--security)
                optimize_security=true
                shift
                ;;
            -p|--performance)
                optimize_performance=true
                shift
                ;;
            -c|--cleanup)
                optimize_cleanup=true
                shift
                ;;
            -u|--ui)
                optimize_ui=true
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果指定了-all，则启用所有优化
    if [ "$optimize_all" = true ]; then
        optimize_dock=true
        optimize_finder=true
        optimize_security=true
        optimize_performance=true
        optimize_cleanup=true
        optimize_ui=true
    fi
    
    # 如果没有指定任何选项，默认执行所有优化
    if [ "$optimize_dock" = false ] && [ "$optimize_finder" = false ] && \
       [ "$optimize_security" = false ] && [ "$optimize_performance" = false ] && \
       [ "$optimize_cleanup" = false ] && [ "$optimize_ui" = false ]; then
        optimize_dock=true
        optimize_finder=true
        optimize_security=true
        optimize_performance=true
        optimize_cleanup=true
        optimize_ui=true
    fi
    
    # 导出变量供其他函数使用
    export OPTIMIZE_DOCK="$optimize_dock"
    export OPTIMIZE_FINDER="$optimize_finder"
    export OPTIMIZE_SECURITY="$optimize_security"
    export OPTIMIZE_PERFORMANCE="$optimize_performance"
    export OPTIMIZE_CLEANUP="$optimize_cleanup"
    export OPTIMIZE_UI="$optimize_ui"
}

# 优化Dock设置
optimize_dock() {
    if [ "$OPTIMIZE_DOCK" = false ]; then
        return
    fi
    
    echo -e "${BLUE}==== 优化Dock设置 ====${NC}"
    
    # 自动隐藏Dock
    echo "启用自动隐藏Dock..."
    defaults write com.apple.dock autohide -bool true
    
    # 减少Dock显示延迟
    echo "减少Dock显示延迟..."
    defaults write com.apple.dock autohide-delay -float 0
    
    # 设置Dock图标大小
    echo "设置Dock图标大小..."
    defaults write com.apple.dock tilesize -int 40
    
    # 禁用Dock动画效果
    echo "禁用Dock动画效果..."
    defaults write com.apple.dock launchanim -bool false
    
    # 重启Dock
    echo "重启Dock..."
    killall Dock 2>/dev/null || true
    
    echo -e "${GREEN}Dock优化完成${NC}"
    echo ""
}

# 优化Finder设置
optimize_finder() {
    if [ "$OPTIMIZE_FINDER" = false ]; then
        return
    fi
    
    echo -e "${BLUE}==== 优化Finder设置 ====${NC}"
    
    # 显示隐藏文件
    echo "显示隐藏文件..."
    defaults write com.apple.finder AppleShowAllFiles -bool true
    
    # 显示文件扩展名
    echo "显示文件扩展名..."
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    
    # 显示状态栏
    echo "显示状态栏..."
    defaults write com.apple.finder ShowStatusBar -bool true
    
    # 显示路径栏
    echo "显示路径栏..."
    defaults write com.apple.finder ShowPathbar -bool true
    
    # 禁用警告
    echo "禁用文件更改警告..."
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
    
    # 设置默认视图为列表视图
    echo "设置默认视图为列表视图..."
    defaults write com.apple.finder FK_PreferredViewStyle -string "clmv"
    
    # 重启Finder
    echo "重启Finder..."
    killall Finder 2>/dev/null || true
    
    echo -e "${GREEN}Finder优化完成${NC}"
    echo ""
}

# 增强安全设置
optimize_security() {
    if [ "$OPTIMIZE_SECURITY" = false ]; then
        return
    fi
    
    echo -e "${BLUE}==== 增强安全设置 ====${NC}"
    
    # 启用防火墙
    echo "启用防火墙..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || true
    
    # 启用隐形模式
    echo "启用隐形模式..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null || true
    
    # 禁用自动打开安全应用
    echo "禁用自动打开安全应用..."
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    
    # 禁用自动运行安全应用
    echo "禁用自动运行安全应用..."
    defaults write com.apple.LaunchServices LSQuarantine -bool false
    
    # 启用文件保险箱
    echo "检查FileVault状态..."
    local fde_status=$(fdesetup status 2>/dev/null || echo "无法获取状态")
    echo "FileVault状态: $fde_status"
    
    echo -e "${GREEN}安全设置完成${NC}"
    echo ""
}

# 性能优化
optimize_performance() {
    if [ "$OPTIMIZE_PERFORMANCE" = false ]; then
        return
    fi
    
    echo -e "${BLUE}==== 性能优化 ====${NC}"
    
    # 禁用动画效果
    echo "禁用动画效果..."
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    
    # 禁用仪表盘
    echo "禁用仪表盘..."
    defaults write com.apple.dashboard mcx-disabled -bool true
    
    # 禁用Spotlight索引
    echo "禁用Spotlight索引..."
    sudo mdutil -i off / 2>/dev/null || true
    
    # 禁用TimeMachine本地快照
    echo "禁用TimeMachine本地快照..."
    sudo tmutil disablelocal 2>/dev/null || true
    
    # 优化内存管理
    echo "优化内存管理..."
    sudo purge 2>/dev/null || true
    
    echo -e "${GREEN}性能优化完成${NC}"
    echo ""
}

# 系统清理
optimize_cleanup() {
    if [ "$OPTIMIZE_CLEANUP" = false ]; then
        return
    fi
    
    echo -e "${BLUE}==== 系统清理 ====${NC}"
    
    # 清理系统缓存
    echo "清理系统缓存..."
    sudo rm -rf /Library/Caches/* 2>/dev/null || true
    rm -rf ~/Library/Caches/* 2>/dev/null || true
    
    # 清理临时文件
    echo "清理临时文件..."
    sudo rm -rf /tmp/* 2>/dev/null || true
    rm -rf ~/tmp/* 2>/dev/null || true
    
    # 清理日志文件
    echo "清理日志文件..."
    sudo rm -rf /var/log/* 2>/dev/null || true
    rm -rf ~/Library/Logs/* 2>/dev/null || true
    
    # 清理下载文件夹
    echo "清理下载文件夹..."
    rm -rf ~/Downloads/.DS_Store 2>/dev/null || true
    find ~/Downloads -name ".DS_Store" -delete 2>/dev/null || true
    
    # 清理垃圾箱
    echo "清理垃圾箱..."
    rm -rf ~/.Trash/* 2>/dev/null || true
    
    # 重建Spotlight索引
    echo "重建Spotlight索引..."
    sudo mdutil -E / 2>/dev/null || true
    
    echo -e "${GREEN}系统清理完成${NC}"
    echo ""
}

# UI界面优化
optimize_ui() {
    if [ "$OPTIMIZE_UI" = false ]; then
        return
    fi
    
    echo -e "${BLUE}==== UI界面优化 ====${NC}"
    
    # 禁用透明度
    echo "禁用透明度..."
    defaults write com.apple.universalaccess reduceTransparency -bool true
    
    # 设置强调色
    echo "设置强调色..."
    defaults write NSGlobalDomain AppleAccentColor -int 1
    
    # 设置高亮颜色
    echo "设置高亮颜色..."
    defaults write NSGlobalDomain AppleHighlightColor -string "0.968627 0.831373 0.501961"
    
    # 禁用自动纠错
    echo "禁用自动纠错..."
    defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
    
    # 禁用智能引号
    echo "禁用智能引号..."
    defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
    
    # 禁用智能破折号
    echo "禁用智能破折号..."
    defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
    
    # 设置截图保存位置
    echo "设置截图保存位置..."
    local screenshot_dir="$HOME/Desktop/Screenshots"
    mkdir -p "$screenshot_dir"
    defaults write com.apple.screencapture location -string "$screenshot_dir"
    
    # 禁用截图阴影
    echo "禁用截图阴影..."
    defaults write com.apple.screencapture disable-shadow -bool true
    
    echo -e "${GREEN}UI界面优化完成${NC}"
    echo ""
}

# 显示优化摘要
show_optimization_summary() {
    echo -e "${BLUE}==== 优化摘要 ====${NC}"
    
    echo "已执行的优化:"
    [ "$OPTIMIZE_DOCK" = true ] && echo "  ✓ Dock设置优化"
    [ "$OPTIMIZE_FINDER" = true ] && echo "  ✓ Finder设置优化"
    [ "$OPTIMIZE_SECURITY" = true ] && echo "  ✓ 安全设置增强"
    [ "$OPTIMIZE_PERFORMANCE" = true ] && echo "  ✓ 性能优化"
    [ "$OPTIMIZE_CLEANUP" = true ] && echo "  ✓ 系统清理"
    [ "$OPTIMIZE_UI" = true ] && echo "  ✓ UI界面优化"
    
    echo ""
    echo "注意：某些优化可能需要重启系统才能完全生效"
    echo ""
}

# 主函数
main() {
    parse_args "$@"
    
    optimize_dock
    optimize_finder
    optimize_security
    optimize_performance
    optimize_cleanup
    optimize_ui
    
    show_optimization_summary
}

# 执行主函数
main "$@"

echo "======================================"
echo -e "${GREEN}系统优化完成！${NC}"
echo "结束时间: $(date)"
echo "日志文件: $LOG_FILE"
echo ""
echo "建议重启系统以确保所有优化生效"