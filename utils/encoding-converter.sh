#!/bin/bash

# 批量文件编码转换工具
# 功能：批量转换文件编码格式
# 使用方法：./encoding-converter.sh [目录] [选项]

set -euo pipefail

# 默认参数
TARGET_DIR="."
FROM_ENCODING="auto"
TO_ENCODING="UTF-8"
FILE_PATTERNS=("*.txt" "*.csv" "*.md" "*.py" "*.sh" "*.html" "*.css" "*.js" "*.xml" "*.json")
RECURSIVE=false
BACKUP=true
DRY_RUN=false
VERBOSE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "批量文件编码转换工具使用说明:"
    echo "用法: $0 [目录] [选项]"
    echo ""
    echo "参数:"
    echo "  目录                目标目录（默认: 当前目录）"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -f, --from ENC      源编码（默认: auto）"
    echo "  -t, --to ENC        目标编码（默认: UTF-8）"
    echo "  -p, --pattern PATT  文件模式（可多次使用）"
    echo "  -r, --recursive     递归处理子目录"
    echo "  -b, --backup        保留备份文件（默认启用）"
    echo "  --no-backup         不保留备份文件"
    echo "  -d, --dry-run       模拟运行，不实际转换"
    echo "  -v, --verbose       详细输出"
    echo ""
    echo "常用编码:"
    echo "  UTF-8, UTF-16, GB2312, GBK, GB18030, BIG5, ISO-8859-1"
    echo ""
    echo "示例:"
    echo "  $0 /path/to/files -f GBK -t UTF-8"
    echo "  $0 -r -p \"*.txt\" -p \"*.csv\""
    echo "  $0 -f auto -t UTF-8 --no-backup"
    echo "  $0 -d -v  # 模拟运行，详细输出"
}

# 解析命令行参数
parse_args() {
    TARGET_DIR="${1:-.}"
    shift 2>/dev/null || true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--from)
                FROM_ENCODING="$2"
                shift 2
                ;;
            -t|--to)
                TO_ENCODING="$2"
                shift 2
                ;;
            -p|--pattern)
                FILE_PATTERNS+=("$2")
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            --no-backup)
                BACKUP=false
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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

# 检查参数
check_args() {
    # 检查目录
    if [ ! -d "$TARGET_DIR" ]; then
        echo -e "${RED}错误: 目录不存在: $TARGET_DIR${NC}"
        exit 1
    fi
    
    # 检查iconv是否可用
    if ! command -v iconv >/dev/null 2>&1; then
        echo -e "${RED}错误: 未找到iconv命令${NC}"
        echo "请安装iconv工具"
        exit 1
    fi
    
    # 检查file命令是否可用
    if ! command -v file >/dev/null 2>&1; then
        echo -e "${RED}错误: 未找到file命令${NC}"
        echo "请安装file工具"
        exit 1
    fi
}

# 检测文件编码
detect_encoding() {
    local file="$1"
    local encoding
    
    # 使用file命令检测编码
    encoding=$(file -b --mime-encoding "$file" 2>/dev/null | cut -d'=' -f2)
    
    # 处理一些特殊情况
    case "$encoding" in
        "utf-8")
            echo "UTF-8"
            ;;
        "us-ascii")
            echo "ASCII"
            ;;
        "iso-8859-1")
            echo "ISO-8859-1"
            ;;
        "gb2312"|"gbk")
            echo "GBK"
            ;;
        "gb18030")
            echo "GB18030"
            ;;
        "big5")
            echo "BIG5"
            ;;
        "utf-16le"|"utf-16be")
            echo "UTF-16"
            ;;
        *)
            echo "$encoding"
            ;;
    esac
}

# 检查文件是否需要转换
needs_conversion() {
    local file="$1"
    local from_enc="$2"
    local to_enc="$3"
    local detected_enc
    
    # 检测文件编码
    detected_enc=$(detect_encoding "$file")
    
    if [ "$VERBOSE" = true ]; then
        echo "  检测编码: $detected_enc"
    fi
    
    # 如果是自动检测，使用检测到的编码
    if [ "$from_enc" = "auto" ]; then
        from_enc="$detected_enc"
    fi
    
    # 检查是否需要转换
    if [ "$from_enc" = "$to_enc" ] || [ "$from_enc" = "ASCII" -a "$to_enc" = "UTF-8" ]; then
        return 1  # 不需要转换
    fi
    
    return 0  # 需要转换
}

# 转换文件编码
convert_file() {
    local file="$1"
    local from_enc="$2"
    local to_enc="$3"
    local temp_file="${file}.tmp"
    local backup_file="${file}.bak"
    
    # 检测文件编码
    if [ "$from_enc" = "auto" ]; then
        from_enc=$(detect_encoding "$file")
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo "  转换: $from_enc -> $to_enc"
    fi
    
    # 执行转换
    if iconv -f "$from_enc" -t "$to_enc" "$file" > "$temp_file" 2>/dev/null; then
        # 转换成功
        if [ "$DRY_RUN" = false ]; then
            # 创建备份
            if [ "$BACKUP" = true ]; then
                cp "$file" "$backup_file"
                if [ "$VERBOSE" = true ]; then
                    echo "  备份: $backup_file"
                fi
            fi
            
            # 替换原文件
            mv "$temp_file" "$file"
            
            if [ "$VERBOSE" = true ]; then
                echo "  完成: $file"
            fi
        else
            rm -f "$temp_file"
            echo "  [模拟] $file"
        fi
        
        return 0
    else
        # 转换失败
        rm -f "$temp_file"
        echo -e "  ${RED}转换失败: $file${NC}"
        return 1
    fi
}

# 查找文件
find_files() {
    local dir="$1"
    local recursive="$2"
    local patterns=("${@:3}")
    
    local find_cmd="find \"$dir\" -type f"
    
    if [ "$recursive" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    # 添加文件模式
    for pattern in "${patterns[@]}"; do
        find_cmd="$find_cmd -name \"$pattern\" -o"
    done
    
    # 移除最后的 -o
    find_cmd="${find_cmd% -o}"
    
    # 执行查找
    eval "$find_cmd"
}

# 批量转换
convert_files() {
    local dir="$1"
    local from_enc="$2"
    local to_enc="$3"
    local recursive="$4"
    local patterns=("${@:5}")
    
    echo "======================================"
    echo "        批量编码转换"
    echo "======================================"
    echo "目标目录: $dir"
    echo "源编码: $from_enc"
    echo "目标编码: $to_enc"
    echo "文件模式: ${patterns[*]}"
    echo "递归处理: $recursive"
    echo "保留备份: $BACKUP"
    echo "模拟运行: $DRY_RUN"
    echo ""
    
    # 查找文件
    local files=()
    while IFS= read -r file; do
        files+=("$file")
    done < <(find_files "$dir" "$recursive" "${patterns[@]}")
    
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${YELLOW}未找到匹配的文件${NC}"
        return
    fi
    
    echo "找到 ${#files[@]} 个文件"
    echo ""
    
    # 转换文件
    local converted=0
    local failed=0
    local skipped=0
    
    for file in "${files[@]}"; do
        echo -e "${BLUE}处理: $file${NC}"
        
        # 检查是否需要转换
        if needs_conversion "$file" "$from_enc" "$to_enc"; then
            # 转换文件
            if convert_file "$file" "$from_enc" "$to_enc"; then
                converted=$((converted + 1))
            else
                failed=$((failed + 1))
            fi
        else
            echo "  跳过: 编码已是 $to_enc"
            skipped=$((skipped + 1))
        fi
        
        echo ""
    done
    
    # 输出统计
    echo "======================================"
    echo "转换统计:"
    echo "  总文件数: ${#files[@]}"
    echo -e "  转换成功: ${GREEN}$converted${NC}"
    echo -e "  转换失败: ${RED}$failed${NC}"
    echo -e "  跳过文件: ${YELLOW}$skipped${NC}"
    
    if [ "$BACKUP" = true ] && [ "$DRY_RUN" = false ] && [ "$converted" -gt 0 ]; then
        echo ""
        echo "备份文件位置: $(find "$dir" -name "*.bak" | wc -l) 个"
    fi
}

# 清理备份文件
clean_backups() {
    local dir="$1"
    
    echo -e "${BLUE}清理备份文件...${NC}"
    
    local backup_count=0
    while IFS= read -r backup_file; do
        rm "$backup_file"
        backup_count=$((backup_count + 1))
        
        if [ "$VERBOSE" = true ]; then
            echo "  删除: $backup_file"
        fi
    done < <(find "$dir" -name "*.bak")
    
    echo -e "${GREEN}已删除 $backup_count 个备份文件${NC}"
}

# 主函数
main() {
    parse_args "$@"
    check_args
    
    # 检查是否是清理备份
    if [ "$1" = "--clean-backups" ]; then
        clean_backups "$TARGET_DIR"
        exit 0
    fi
    
    # 执行转换
    convert_files "$TARGET_DIR" "$FROM_ENCODING" "$TO_ENCODING" "$RECURSIVE" "${FILE_PATTERNS[@]}"
    
    echo ""
    echo "======================================"
    echo -e "${GREEN}编码转换完成！${NC}"
    
    # 提示清理备份
    if [ "$BACKUP" = true ] && [ "$DRY_RUN" = false ]; then
        echo ""
        echo -e "${YELLOW}提示: 如需清理备份文件，请运行:${NC}"
        echo "  $0 --clean-backups"
    fi
}

# 执行主函数
main "$@"