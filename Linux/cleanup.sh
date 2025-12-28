#!/bin/bash

# 系统清理脚本
# 功能：清理系统临时文件、日志、缓存等释放磁盘空间
# 使用方法：./cleanup.sh [选项]

set -euo pipefail

# 默认参数
DRY_RUN=false
VERBOSE=false
CLEAN_TEMP=true
CLEAN_LOGS=false
CLEAN_CACHE=false
CLEAN_PACKAGES=false
LOG_FILE="/tmp/cleanup-$(date +%Y%m%d_%H%M%S).log"
SPACE_SAVED=0

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "系统清理脚本使用说明:"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -d, --dry-run       模拟运行，不实际删除文件"
    echo "  -v, --verbose       详细输出"
    echo "  -t, --temp          清理临时文件（默认启用）"
    echo "  -l, --logs          清理旧日志文件"
    echo "  -c, --cache         清理应用程序缓存"
    echo "  -p, --packages      清理不需要的软件包"
    echo "  -a, --all           清理所有项目（等同于 -tlcp）"
    echo ""
    echo "示例:"
    echo "  $0 -d               # 模拟运行，查看会清理什么"
    echo "  $0 -v -t -c         # 详细模式清理临时文件和缓存"
    echo "  $0 -a               # 清理所有项目"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -t|--temp)
                CLEAN_TEMP=true
                shift
                ;;
            -l|--logs)
                CLEAN_LOGS=true
                shift
                ;;
            -c|--cache)
                CLEAN_CACHE=true
                shift
                ;;
            -p|--packages)
                CLEAN_PACKAGES=true
                shift
                ;;
            -a|--all)
                CLEAN_TEMP=true
                CLEAN_LOGS=true
                CLEAN_CACHE=true
                CLEAN_PACKAGES=true
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

# 创建日志文件
setup_logging() {
    touch "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    echo "======================================"
    echo "          系统清理工具"
    echo "======================================"
    echo "开始时间: $(date)"
    echo "模拟运行: $DRY_RUN"
    echo "详细输出: $VERBOSE"
    echo ""
}

# 计算目录大小
get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | cut -f1 || echo 0
    else
        echo 0
    fi
}

# 格式化大小
format_size() {
    local size=$1
    if [ "$size" -lt 1024 ]; then
        echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
        echo "$(( size / 1024 ))KB"
    elif [ "$size" -lt 1073741824 ]; then
        echo "$(( size / 1048576 ))MB"
    else
        echo "$(( size / 1073741824 ))GB"
    fi
}

# 清理临时文件
clean_temp_files() {
    echo -e "${BLUE}==== 清理临时文件 ====${NC}"
    
    local temp_dirs=(
        "/tmp"
        "/var/tmp"
        "$HOME/.cache"
        "$HOME/tmp"
    )
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size_before=$(get_dir_size "$dir")
            
            if [ "$VERBOSE" = true ]; then
                echo "处理目录: $dir (大小: $(format_size $size_before))"
            fi
            
            if [ "$DRY_RUN" = false ]; then
                # 保留最近7天内的文件
                find "$dir" -type f -atime +7 -delete 2>/dev/null || true
                find "$dir" -type d -empty -delete 2>/dev/null || true
            fi
            
            local size_after=$(get_dir_size "$dir")
            local saved=$((size_before - size_after))
            SPACE_SAVED=$((SPACE_SAVED + saved))
            
            if [ "$saved" -gt 0 ] || [ "$VERBOSE" = true ]; then
                echo -e "  $dir: 释放 $(format_size $saved)"
            fi
        fi
    done
    
    echo ""
}

# 清理日志文件
clean_log_files() {
    echo -e "${BLUE}==== 清理日志文件 ====${NC}"
    
    local log_dirs=(
        "/var/log"
        "$HOME/.local/share/logs"
        "$HOME/.cache/logs"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ "$VERBOSE" = true ]; then
                echo "处理目录: $dir"
            fi
            
            # 清理旧的日志文件（保留最近7天）
            while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then
                    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
                    
                    if [ "$DRY_RUN" = false ]; then
                        > "$file"  # 清空文件而不是删除，保留权限
                    fi
                    
                    SPACE_SAVED=$((SPACE_SAVED + size))
                    if [ "$VERBOSE" = true ] || [ "$size" -gt 0 ]; then
                        echo -e "  清空日志: $file (释放 $(format_size $size))"
                    fi
                fi
            done < <(find "$dir" -name "*.log" -type f -mtime +7 -print0 2>/dev/null)
        fi
    done
    
    # 清理系统日志轮转
    if [ -f "/etc/logrotate.conf" ] && command -v logrotate >/dev/null 2>&1; then
        if [ "$DRY_RUN" = false ]; then
            logrotate -f /etc/logrotate.conf >/dev/null 2>&1 || true
        fi
        echo -e "  执行日志轮转"
    fi
    
    echo ""
}

# 清理应用程序缓存
clean_app_cache() {
    echo -e "${BLUE}==== 清理应用程序缓存 ====${NC}"
    
    local cache_dirs=(
        "$HOME/.cache"
        "$HOME/.thumbnails"
        "/var/cache"
    )
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local size_before=$(get_dir_size "$dir")
            
            if [ "$VERBOSE" = true ]; then
                echo "处理目录: $dir (大小: $(format_size $size_before))"
            fi
            
            if [ "$DRY_RUN" = false ]; then
                # 清理超过30天的缓存文件
                find "$dir" -type f -atime +30 -delete 2>/dev/null || true
                find "$dir" -type d -empty -delete 2>/dev/null || true
            fi
            
            local size_after=$(get_dir_size "$dir")
            local saved=$((size_before - size_after))
            SPACE_SAVED=$((SPACE_SAVED + saved))
            
            if [ "$saved" -gt 0 ] || [ "$VERBOSE" = true ]; then
                echo -e "  $dir: 释放 $(format_size $saved)"
            fi
        fi
    done
    
    echo ""
}

# 清理不需要的软件包
clean_packages() {
    echo -e "${BLUE}==== 清理不需要的软件包 ====${NC}"
    
    # Debian/Ubuntu系统
    if command -v apt >/dev/null 2>&1; then
        echo "检测到APT包管理器"
        
        if [ "$DRY_RUN" = false ]; then
            apt-get autoremove -y >/dev/null 2>&1 || true
            apt-get autoclean >/dev/null 2>&1 || true
        fi
        echo -e "  清理APT缓存和不需要的包"
        
    # RedHat/CentOS系统
    elif command -v yum >/dev/null 2>&1; then
        echo "检测到YUM包管理器"
        
        if [ "$DRY_RUN" = false ]; then
            yum autoremove -y >/dev/null 2>&1 || true
            yum clean all >/dev/null 2>&1 || true
        fi
        echo -e "  清理YUM缓存和不需要的包"
        
    # Arch Linux
    elif command -v pacman >/dev/null 2>&1; then
        echo "检测到Pacman包管理器"
        
        if [ "$DRY_RUN" = false ]; then
            pacman -Rns $(pacman -Qtdq) >/dev/null 2>&1 || true
            pacman -Scc --noconfirm >/dev/null 2>&1 || true
        fi
        echo -e "  清理Pacman缓存和不需要的包"
    else
        echo "未检测到支持的包管理器"
    fi
    
    echo ""
}

# 主函数
main() {
    parse_args "$@"
    setup_logging
    
    if [ "$CLEAN_TEMP" = true ]; then
        clean_temp_files
    fi
    
    if [ "$CLEAN_LOGS" = true ]; then
        clean_log_files
    fi
    
    if [ "$CLEAN_CACHE" = true ]; then
        clean_app_cache
    fi
    
    if [ "$CLEAN_PACKAGES" = true ]; then
        clean_packages
    fi
    
    echo "======================================"
    echo -e "${GREEN}清理完成！${NC}"
    echo -e "总释放空间: ${YELLOW}$(format_size $SPACE_SAVED)${NC}"
    echo "结束时间: $(date)"
    echo "日志文件: $LOG_FILE"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}注意：这是模拟运行，没有实际删除文件${NC}"
    fi
}

# 执行主函数
main "$@"