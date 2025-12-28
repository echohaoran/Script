#!/bin/bash

# macOS磁盘管理脚本
# 功能：分析、清理和管理磁盘空间
# 使用方法：./disk-manager.sh [选项]

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/disk-manager-$(date +%Y%m%d_%H%M%S).log"

# 创建日志文件
touch "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "       macOS磁盘管理工具"
echo "======================================"
echo "开始时间: $(date)"
echo ""

# 显示帮助信息
show_help() {
    echo "macOS磁盘管理脚本使用说明:"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -a, --analyze       分析磁盘使用情况"
    echo "  -c, --cleanup       清理磁盘空间"
    echo "  -d, --duplicate     查找重复文件"
    echo "  -b, --bigfiles      查找大文件"
    echo "  -s, --snapshot      管理Time Machine快照"
    echo "  -r, --repair        检查和修复磁盘"
    echo ""
    echo "示例:"
    echo "  $0 -a               # 分析磁盘使用情况"
    echo "  $0 -c               # 清理磁盘空间"
    echo "  $0 -b               # 查找大文件"
    echo "  $0 -d /path/to/dir  # 查找重复文件"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--analyze)
                ANALYZE=true
                shift
                ;;
            -c|--cleanup)
                CLEANUP=true
                shift
                ;;
            -d|--duplicate)
                DUPLICATE=true
                SEARCH_PATH="${2:-$HOME}"
                shift 2
                ;;
            -b|--bigfiles)
                BIGFILES=true
                SEARCH_PATH="${2:-$HOME}"
                shift 2
                ;;
            -s|--snapshot)
                SNAPSHOT=true
                shift
                ;;
            -r|--repair)
                REPAIR=true
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 分析磁盘使用情况
analyze_disk() {
    if [ "${ANALYZE:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 磁盘使用情况分析 ====${NC}"
    
    # 显示磁盘空间使用情况
    echo "磁盘空间使用情况:"
    df -h
    
    echo ""
    echo "磁盘详细信息:"
    diskutil list
    
    echo ""
    echo "各目录空间占用:"
    
    # 分析主要目录
    local dirs=("$HOME" "/Applications" "/Library" "/System" "/Users" "/private")
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        fi
    done
    
    echo ""
    echo "用户目录详细分析:"
    if [ -d "$HOME" ]; then
        local user_dirs=("$HOME/Documents" "$HOME/Downloads" "$HOME/Desktop" "$HOME/Movies" "$HOME/Music" "$HOME/Pictures" "$HOME/Library")
        
        for dir in "${user_dirs[@]}"; do
            if [ -d "$dir" ]; then
                local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                echo "  $(basename "$dir"): $size"
            fi
        done
    fi
    
    echo ""
}

# 清理磁盘空间
cleanup_disk() {
    if [ "${CLEANUP:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 清理磁盘空间 ====${NC}"
    
    # 清理下载文件夹
    echo "清理下载文件夹..."
    if [ -d "$HOME/Downloads" ]; then
        find "$HOME/Downloads" -type f -atime +30 -delete 2>/dev/null || true
        echo "  已删除30天未访问的下载文件"
    fi
    
    # 清理垃圾箱
    echo "清理垃圾箱..."
    rm -rf "$HOME/.Trash/"* 2>/dev/null || true
    echo "  已清空垃圾箱"
    
    # 清理系统缓存
    echo "清理系统缓存..."
    sudo rm -rf /Library/Caches/* 2>/dev/null || true
    rm -rf "$HOME/Library/Caches/"* 2>/dev/null || true
    echo "  已清理系统缓存"
    
    # 清理日志文件
    echo "清理日志文件..."
    sudo rm -rf /var/log/asl/*.asl 2>/dev/null || true
    rm -rf "$HOME/Library/Logs/"* 2>/dev/null || true
    echo "  已清理日志文件"
    
    # 清理iOS备份
    echo "清理iOS备份..."
    rm -rf "$HOME/Library/Application Support/MobileSync/Backup/"* 2>/dev/null || true
    echo "  已清理iOS备份"
    
    # 清理XCode缓存
    echo "清理XCode缓存..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
    echo "  已清理XCode缓存"
    
    # 清理Docker缓存
    if command -v docker >/dev/null 2>&1; then
        echo "清理Docker缓存..."
        docker system prune -f 2>/dev/null || true
        echo "  已清理Docker缓存"
    fi
    
    # 清理Homebrew缓存
    if command -v brew >/dev/null 2>&1; then
        echo "清理Homebrew缓存..."
        brew cleanup --prune=30 2>/dev/null || true
        echo "  已清理Homebrew缓存"
    fi
    
    echo -e "${GREEN}磁盘清理完成${NC}"
    echo ""
}

# 查找重复文件
find_duplicates() {
    if [ "${DUPLICATE:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 查找重复文件 ====${NC}"
    echo "搜索路径: $SEARCH_PATH"
    
    # 检查是否安装了fdupes
    if ! command -v fdupes >/dev/null 2>&1; then
        echo -e "${YELLOW}未安装fdupes，尝试安装...${NC}"
        if command -v brew >/dev/null 2>&1; then
            brew install fdupes
        else
            echo -e "${RED}无法安装fdupes，请手动安装后重试${NC}"
            return
        fi
    fi
    
    # 查找重复文件
    echo "查找重复文件..."
    fdupes -r "$SEARCH_PATH" | head -n 50
    
    echo ""
    echo "生成重复文件报告..."
    local report_file="$HOME/duplicate-files-$(date +%Y%m%d_%H%M%S).txt"
    fdupes -r "$SEARCH_PATH" > "$report_file"
    echo "报告已保存到: $report_file"
    
    echo ""
}

# 查找大文件
find_big_files() {
    if [ "${BIGFILES:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 查找大文件 ====${NC}"
    echo "搜索路径: $SEARCH_PATH"
    
    # 查找大于100MB的文件
    echo "大于100MB的文件:"
    find "$SEARCH_PATH" -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -n 20
    
    echo ""
    echo "大于1GB的文件:"
    find "$SEARCH_PATH" -type f -size +1G -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -n 10
    
    echo ""
}

# 管理Time Machine快照
manage_snapshots() {
    if [ "${SNAPSHOT:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 管理Time Machine快照 ====${NC}"
    
    # 列出所有快照
    echo "当前Time Machine快照:"
    sudo tmutil listlocalsnapshots / 2>/dev/null || echo "无法获取快照列表"
    
    echo ""
    echo "删除所有本地快照..."
    # 获取所有快照并删除
    local snapshots=$(sudo tmutil listlocalsnapshots / 2>/dev/null | grep -o 'com.apple.TimeMachine.*-[0-9]*' || true)
    
    for snapshot in $snapshots; do
        echo "删除快照: $snapshot"
        sudo tmutil deletelocalsnapshots $snapshot 2>/dev/null || true
    done
    
    echo ""
    echo "禁用本地快照..."
    sudo tmutil disablelocal 2>/dev/null || true
    
    echo -e "${GREEN}Time Machine快照管理完成${NC}"
    echo ""
}

# 检查和修复磁盘
repair_disk() {
    if [ "${REPAIR:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 检查和修复磁盘 ====${NC}"
    
    # 获取启动磁盘
    local startup_disk=$(diskutil info / | grep "Device Node:" | awk '{print $3}')
    
    echo "启动磁盘: $startup_disk"
    
    # 验证磁盘
    echo "验证磁盘..."
    sudo diskutil verifyVolume "$startup_disk" || echo "磁盘验证完成"
    
    echo ""
    echo "修复磁盘权限..."
    sudo diskutil repairPermissions "$startup_disk" || echo "权限修复完成"
    
    echo ""
    echo "重建Spotlight索引..."
    sudo mdutil -E / 2>/dev/null || echo "索引重建完成"
    
    echo -e "${GREEN}磁盘检查和修复完成${NC}"
    echo ""
}

# 显示磁盘健康状态
show_disk_health() {
    echo -e "${BLUE}==== 磁盘健康状态 ====${NC}"
    
    # 获取磁盘信息
    local disks=$(diskutil list | grep "^/dev/")
    
    while IFS= read -r disk; do
        local disk_name=$(echo "$disk" | awk '{print $1}')
        echo "检查磁盘: $disk_name"
        
        # 获取磁盘信息
        diskutil info "$disk_name" | grep -E "Device Node|Volume Name|File System|Partition Type|Device / Media Name|Total Size|Free Space|Device Identifier|IOKit"
        
        # 检查SMART状态
        if command -v diskutil >/dev/null 2>&1; then
            local smart_status=$(diskutil info "$disk_name" | grep "SMART Status" | awk -F": " '{print $2}')
            echo "SMART状态: $smart_status"
        fi
        
        echo ""
    done <<< "$disks"
}

# 主函数
main() {
    parse_args "$@"
    
    # 如果没有指定任何选项，默认执行分析
    if [ "${ANALYZE:-false}" != true ] && [ "${CLEANUP:-false}" != true ] && \
       [ "${DUPLICATE:-false}" != true ] && [ "${BIGFILES:-false}" != true ] && \
       [ "${SNAPSHOT:-false}" != true ] && [ "${REPAIR:-false}" != true ]; then
        ANALYZE=true
    fi
    
    show_disk_health
    analyze_disk
    cleanup_disk
    find_duplicates
    find_big_files
    manage_snapshots
    repair_disk
}

# 执行主函数
main "$@"

echo "======================================"
echo -e "${GREEN}磁盘管理完成！${NC}"
echo "结束时间: $(date)"
echo "日志文件: $LOG_FILE"