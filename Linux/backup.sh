#!/bin/bash

# 备份脚本
# 功能：备份指定目录到指定位置，支持压缩和增量备份
# 使用方法：./backup.sh [源目录] [目标目录] [备份模式]
# 备份模式：full（完整备份）、incremental（增量备份）

set -euo pipefail

# 默认参数
SOURCE_DIR=""
TARGET_DIR=""
BACKUP_MODE="full"
BACKUP_NAME=""
LOG_FILE="/tmp/backup-$(date +%Y%m%d_%H%M%S).log"

# 显示帮助信息
show_help() {
    echo "备份脚本使用说明:"
    echo "用法: $0 [源目录] [目标目录] [备份模式]"
    echo ""
    echo "参数:"
    echo "  源目录      要备份的目录路径"
    echo "  目标目录    备份文件存放目录"
    echo "  备份模式    full（完整备份）或 incremental（增量备份），默认为 full"
    echo ""
    echo "示例:"
    echo "  $0 /home/user/documents /backup/documents full"
    echo "  $0 /var/www/html /backup/www incremental"
}

# 检查参数
if [ $# -lt 2 ]; then
    echo "错误：参数不足"
    show_help
    exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"
BACKUP_MODE="${3:-full}"

# 验证源目录
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误：源目录不存在: $SOURCE_DIR"
    exit 1
fi

# 创建目标目录（如果不存在）
mkdir -p "$TARGET_DIR"

# 创建日志文件
touch "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# 生成备份文件名
BACKUP_NAME="backup-$(basename "$SOURCE_DIR")-$(date +%Y%m%d_%H%M%S)"

echo "======================================"
echo "          备份工具"
echo "======================================"
echo "开始时间: $(date)"
echo "源目录: $SOURCE_DIR"
echo "目标目录: $TARGET_DIR"
echo "备份模式: $BACKUP_MODE"
echo "备份名称: $BACKUP_NAME"
echo ""

# 检查必要的工具
check_tools() {
    local missing_tools=()
    
    if ! command -v tar >/dev/null 2>&1; then
        missing_tools+=("tar")
    fi
    
    if [ "$BACKUP_MODE" = "incremental" ] && ! command -v find >/dev/null 2>&1; then
        missing_tools+=("find")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "错误：缺少必要工具: ${missing_tools[*]}"
        echo "请安装缺少的工具后重试"
        exit 1
    fi
}

# 执行完整备份
full_backup() {
    echo "执行完整备份..."
    local archive_path="$TARGET_DIR/$BACKUP_NAME-full.tar.gz"
    
    tar -czf "$archive_path" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
    
    echo "完整备份完成！"
    echo "备份文件: $archive_path"
    echo "备份大小: $(du -h "$archive_path" | cut -f1)"
    
    # 生成备份清单
    local manifest_path="$TARGET_DIR/$BACKUP_NAME-manifest.txt"
    tar -tzf "$archive_path" > "$manifest_path"
    echo "备份清单: $manifest_path"
    echo "文件数量: $(wc -l < "$manifest_path")"
}

# 执行增量备份
incremental_backup() {
    echo "执行增量备份..."
    
    # 查找最新的完整备份
    local latest_full_backup=$(find "$TARGET_DIR" -name "*-full.tar.gz" -type f | sort -r | head -n 1)
    
    if [ -z "$latest_full_backup" ]; then
        echo "警告：未找到完整备份，将执行完整备份"
        full_backup
        return
    fi
    
    echo "参考的完整备份: $latest_full_backup"
    
    # 创建临时目录用于比较
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # 解压完整备份清单
    local full_manifest="$temp_dir/full_manifest.txt"
    tar -tzf "$latest_full_backup" > "$full_manifest"
    
    # 生成当前目录文件清单
    local current_manifest="$temp_dir/current_manifest.txt"
    find "$SOURCE_DIR" -type f -printf "%P\n" | sort > "$current_manifest"
    
    # 找出新增或修改的文件
    local changed_files="$temp_dir/changed_files.txt"
    comm -13 "$full_manifest" "$current_manifest" > "$changed_files"
    
    if [ ! -s "$changed_files" ]; then
        echo "没有发现新增或修改的文件，无需备份"
        return
    fi
    
    # 创建增量备份
    local archive_path="$TARGET_DIR/$BACKUP_NAME-incremental.tar.gz"
    local files_list="$temp_dir/files_to_backup.txt"
    
    # 为增量备份准备文件列表
    while IFS= read -r file; do
        echo "$(basename "$SOURCE_DIR")/$file" >> "$files_list"
    done < "$changed_files"
    
    tar -czf "$archive_path" -C "$(dirname "$SOURCE_DIR")" -T "$files_list"
    
    echo "增量备份完成！"
    echo "备份文件: $archive_path"
    echo "备份大小: $(du -h "$archive_path" | cut -f1)"
    echo "变更文件数量: $(wc -l < "$changed_files")"
    
    # 生成变更清单
    local changed_manifest="$TARGET_DIR/$BACKUP_NAME-changes.txt"
    cp "$changed_files" "$changed_manifest"
    echo "变更清单: $changed_manifest"
}

# 主函数
main() {
    check_tools
    
    case "$BACKUP_MODE" in
        "full")
            full_backup
            ;;
        "incremental")
            incremental_backup
            ;;
        *)
            echo "错误：不支持的备份模式: $BACKUP_MODE"
            echo "支持的备份模式: full, incremental"
            exit 1
            ;;
    esac
    
    echo ""
    echo "备份完成！"
    echo "结束时间: $(date)"
    echo "日志文件: $LOG_FILE"
}

# 执行主函数
main