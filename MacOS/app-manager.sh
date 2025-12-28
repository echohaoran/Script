#!/bin/bash

# macOS应用管理脚本
# 功能：管理macOS应用程序的安装、更新、卸载
# 使用方法：./app-manager.sh [命令] [参数]

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/app-manager-$(date +%Y%m%d_%H%M%S).log"

# 创建日志文件
touch "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "       macOS应用管理工具"
echo "======================================"
echo "开始时间: $(date)"
echo ""

# 显示帮助信息
show_help() {
    echo "macOS应用管理脚本使用说明:"
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  install APP_NAME     安装应用"
    echo "  uninstall APP_NAME   卸载应用"
    echo "  update               更新所有应用"
    echo "  list                 列出已安装应用"
    echo "  search KEYWORD       搜索应用"
    echo "  cleanup              清理应用缓存"
    echo "  help                 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 install firefox"
    echo "  $0 uninstall chrome"
    echo "  $0 update"
    echo "  $0 list"
    echo "  $0 search office"
    echo "  $0 cleanup"
}

# 检查Homebrew是否安装
check_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}错误: 未安装Homebrew${NC}"
        echo "请先安装Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
}

# 安装应用
install_app() {
    local app_name="$1"
    echo -e "${BLUE}==== 安装应用: $app_name ====${NC}"
    
    # 检查是否已安装
    if brew list --cask | grep -i "$app_name" >/dev/null 2>&1; then
        echo -e "${YELLOW}应用 $app_name 已安装${NC}"
        return
    fi
    
    # 搜索应用
    echo "搜索应用: $app_name"
    local search_result=$(brew search --cask "$app_name" | head -n 5)
    
    if [ -z "$search_result" ]; then
        echo -e "${RED}未找到应用: $app_name${NC}"
        return
    fi
    
    echo "搜索结果:"
    echo "$search_result"
    echo ""
    
    # 自动选择第一个匹配项
    local app_to_install=$(echo "$search_result" | head -n 1)
    echo "选择安装: $app_to_install"
    
    # 安装应用
    echo "正在安装 $app_to_install..."
    if brew install --cask "$app_to_install"; then
        echo -e "${GREEN}应用 $app_to_install 安装成功${NC}"
    else
        echo -e "${RED}应用 $app_to_install 安装失败${NC}"
    fi
}

# 卸载应用
uninstall_app() {
    local app_name="$1"
    echo -e "${BLUE}==== 卸载应用: $app_name ====${NC}"
    
    # 查找已安装的应用
    local installed_app=$(brew list --cask | grep -i "$app_name" | head -n 1)
    
    if [ -z "$installed_app" ]; then
        echo -e "${RED}未找到已安装的应用: $app_name${NC}"
        return
    fi
    
    echo "找到应用: $installed_app"
    
    # 卸载应用
    echo "正在卸载 $installed_app..."
    if brew uninstall --cask "$installed_app"; then
        echo -e "${GREEN}应用 $installed_app 卸载成功${NC}"
    else
        echo -e "${RED}应用 $installed_app 卸载失败${NC}"
    fi
}

# 更新所有应用
update_apps() {
    echo -e "${BLUE}==== 更新所有应用 ====${NC}"
    
    # 更新Homebrew
    echo "更新Homebrew..."
    brew update
    
    # 升级所有应用
    echo "升级所有应用..."
    if brew upgrade; then
        echo -e "${GREEN}应用更新成功${NC}"
    else
        echo -e "${RED}应用更新失败${NC}"
    fi
    
    # 清理旧版本
    echo "清理旧版本..."
    brew cleanup
}

# 列出已安装应用
list_apps() {
    echo -e "${BLUE}==== 已安装应用 ====${NC}"
    
    echo "Cask应用:"
    brew list --cask | sort
    
    echo ""
    echo "Formula应用:"
    brew list | sort | head -n 20
    echo "..."
}

# 搜索应用
search_app() {
    local keyword="$1"
    echo -e "${BLUE}==== 搜索应用: $keyword ====${NC}"
    
    brew search --cask "$keyword"
}

# 清理应用缓存
cleanup_cache() {
    echo -e "${BLUE}==== 清理应用缓存 ====${NC}"
    
    # 清理Homebrew缓存
    echo "清理Homebrew缓存..."
    brew cleanup --prune=30
    
    # 清理系统缓存
    echo "清理系统缓存..."
    local cache_dirs=(
        "$HOME/Library/Caches"
        "/Library/Caches"
        "/tmp"
    )
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "清理目录: $dir"
            find "$dir" -name "*" -type f -atime +7 -delete 2>/dev/null || true
        fi
    done
    
    # 清理应用特定缓存
    echo "清理应用缓存..."
    local app_cache_dirs=(
        "$HOME/Library/Caches/com.google.Chrome"
        "$HOME/Library/Caches/com.mozilla.firefox"
        "$HOME/Library/Caches/com.apple.Safari"
    )
    
    for dir in "${app_cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "清理: $dir"
            rm -rf "$dir"/* 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}缓存清理完成${NC}"
}

# 获取应用信息
get_app_info() {
    local app_name="$1"
    echo -e "${BLUE}==== 应用信息: $app_name ====${NC}"
    
    local app_path=$(find /Applications -name "*$app_name*.app" -d 1 2>/dev/null | head -n 1)
    
    if [ -z "$app_path" ]; then
        echo -e "${RED}未找到应用: $app_name${NC}"
        return
    fi
    
    echo "应用路径: $app_path"
    
    if [ -f "$app_path/Contents/Info.plist" ]; then
        echo "版本信息:"
        defaults read "$app_path/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "无法获取版本"
        defaults read "$app_path/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "无法获取构建版本"
    fi
    
    echo "大小:"
    du -sh "$app_path" 2>/dev/null || echo "无法获取大小"
}

# 主函数
main() {
    # 检查命令
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    
    # 检查Homebrew
    check_homebrew
    
    case "$command" in
        "install")
            if [ $# -lt 2 ]; then
                echo -e "${RED}错误: 请指定要安装的应用名称${NC}"
                exit 1
            fi
            install_app "$2"
            ;;
        "uninstall")
            if [ $# -lt 2 ]; then
                echo -e "${RED}错误: 请指定要卸载的应用名称${NC}"
                exit 1
            fi
            uninstall_app "$2"
            ;;
        "update")
            update_apps
            ;;
        "list")
            list_apps
            ;;
        "search")
            if [ $# -lt 2 ]; then
                echo -e "${RED}错误: 请指定搜索关键词${NC}"
                exit 1
            fi
            search_app "$2"
            ;;
        "cleanup")
            cleanup_cache
            ;;
        "info")
            if [ $# -lt 2 ]; then
                echo -e "${RED}错误: 请指定应用名称${NC}"
                exit 1
            fi
            get_app_info "$2"
            ;;
        "help")
            show_help
            ;;
        *)
            echo -e "${RED}未知命令: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"

echo ""
echo "======================================"
echo -e "${GREEN}应用管理完成！${NC}"
echo "结束时间: $(date)"
echo "日志文件: $LOG_FILE"