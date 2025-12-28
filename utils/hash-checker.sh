#!/bin/bash

# 文件哈希校验工具
# 功能：计算和验证文件哈希值
# 使用方法：./hash-checker.sh [文件/目录] [算法]

set -euo pipefail

# 默认参数
ALGORITHM="sha256"
OUTPUT_FILE=""
VERIFY_MODE=false
RECURSIVE=false
VERBOSE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "文件哈希校验工具使用说明:"
    echo "用法: $0 [文件/目录] [算法] [选项]"
    echo ""
    echo "参数:"
    echo "  文件/目录          要计算哈希的文件或目录"
    echo "  算法              哈希算法（默认: sha256）"
    echo ""
    echo "支持的算法:"
    echo "  md5, sha1, sha224, sha256, sha384, sha512"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -o, --output FILE   输出到文件"
    echo "  -v, --verify FILE   验证哈希值"
    echo "  -r, --recursive     递归处理目录"
    echo "  -V, --verbose       详细输出"
    echo ""
    echo "示例:"
    echo "  $0 file.txt                    # 计算文件SHA256哈希"
    echo "  $0 file.txt md5                # 计算文件MD5哈希"
    echo "  $0 directory/ -r               # 递归计算目录哈希"
    echo "  $0 file.txt -o hashes.txt      # 输出到文件"
    echo "  $0 file.txt -v hashes.txt      # 验证哈希值"
}

# 解析命令行参数
parse_args() {
    local args=("$@")
    local i=0
    
    # 获取位置参数
    if [ ${#args[@]} -gt 0 ] && [[ ! "${args[0]}" =~ ^- ]]; then
        TARGET="${args[0]}"
        i=1
    fi
    
    if [ ${#args[@]} -gt $i ] && [[ ! "${args[$i]}" =~ ^- ]]; then
        ALGORITHM="${args[$i]}"
        i=$((i + 1))
    fi
    
    # 处理选项
    while [ $i -lt ${#args[@]} ]; do
        case "${args[$i]}" in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                OUTPUT_FILE="${args[$((i + 1))]}"
                i=$((i + 2))
                ;;
            -v|--verify)
                VERIFY_MODE=true
                VERIFY_FILE="${args[$((i + 1))]}"
                i=$((i + 2))
                ;;
            -r|--recursive)
                RECURSIVE=true
                i=$((i + 1))
                ;;
            -V|--verbose)
                VERBOSE=true
                i=$((i + 1))
                ;;
            *)
                echo "未知选项: ${args[$i]}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查参数
check_args() {
    # 检查目标
    if [ -z "${TARGET:-}" ]; then
        echo -e "${RED}错误: 请指定文件或目录${NC}"
        show_help
        exit 1
    fi
    
    # 检查目标是否存在
    if [ ! -e "$TARGET" ]; then
        echo -e "${RED}错误: 目标不存在: $TARGET${NC}"
        exit 1
    fi
    
    # 检查算法
    local algorithms=("md5" "sha1" "sha224" "sha256" "sha384" "sha512")
    local found=false
    
    for algo in "${algorithms[@]}"; do
        if [ "$ALGORITHM" = "$algo" ]; then
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "${RED}错误: 不支持的算法: $ALGORITHM${NC}"
        echo "支持的算法: ${algorithms[*]}"
        exit 1
    fi
    
    # 检查验证模式
    if [ "$VERIFY_MODE" = true ]; then
        if [ -z "${VERIFY_FILE:-}" ]; then
            echo -e "${RED}错误: 验证模式需要指定哈希文件${NC}"
            exit 1
        fi
        
        if [ ! -f "$VERIFY_FILE" ]; then
            echo -e "${RED}错误: 哈希文件不存在: $VERIFY_FILE${NC}"
            exit 1
        fi
    fi
    
    # 检查递归模式
    if [ "$RECURSIVE" = true ] && [ ! -d "$TARGET" ]; then
        echo -e "${RED}错误: 递归模式只能用于目录${NC}"
        exit 1
    fi
}

# 计算文件哈希
calculate_hash() {
    local file="$1"
    local algorithm="$2"
    
    case "$algorithm" in
        md5)
            md5sum "$file" | cut -d' ' -f1
            ;;
        sha1)
            sha1sum "$file" | cut -d' ' -f1
            ;;
        sha224)
            sha224sum "$file" | cut -d' ' -f1
            ;;
        sha256)
            sha256sum "$file" | cut -d' ' -f1
            ;;
        sha384)
            sha384sum "$file" | cut -d' ' -f1
            ;;
        sha512)
            sha512sum "$file" | cut -d' ' -f1
            ;;
        *)
            echo "未知算法: $algorithm"
            exit 1
            ;;
    esac
}

# 处理单个文件
process_file() {
    local file="$1"
    local relative_path="$2"
    local hash
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}处理文件: $file${NC}"
    fi
    
    hash=$(calculate_hash "$file" "$ALGORITHM")
    echo "$hash  $relative_path"
    
    # 输出到文件
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$hash  $relative_path" >> "$OUTPUT_FILE"
    fi
}

# 处理目录
process_directory() {
    local dir="$1"
    local base_dir="$2"
    
    # 查找文件
    local find_cmd="find \"$dir\" -type f"
    
    if [ "$RECURSIVE" = false ]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi
    
    # 处理每个文件
    while IFS= read -r -d '' file; do
        local relative_path
        if [ "$base_dir" = "$dir" ]; then
            relative_path="${file#$base_dir/}"
        else
            relative_path="${file#$base_dir/}"
        fi
        
        process_file "$file" "$relative_path"
    done < <(eval "$find_cmd -print0")
}

# 验证哈希
verify_hashes() {
    local hash_file="$1"
    local target="$2"
    local errors=0
    local total=0
    
    echo "======================================"
    echo "          哈希验证"
    echo "======================================"
    echo "哈希文件: $hash_file"
    echo "目标: $target"
    echo ""
    
    # 读取哈希文件
    while IFS= read -r line; do
        # 跳过空行和注释
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        
        # 解析哈希和文件路径
        local expected_hash=$(echo "$line" | awk '{print $1}')
        local file_path=$(echo "$line" | cut -d' ' -f3-)
        
        # 构建完整路径
        local full_path
        if [ -d "$target" ]; then
            full_path="$target/$file_path"
        else
            full_path="$target"
        fi
        
        total=$((total + 1))
        
        # 检查文件是否存在
        if [ ! -f "$full_path" ]; then
            echo -e "${RED}文件不存在: $full_path${NC}"
            errors=$((errors + 1))
            continue
        fi
        
        # 计算实际哈希
        local actual_hash=$(calculate_hash "$full_path" "$ALGORITHM")
        
        # 比较哈希
        if [ "$expected_hash" = "$actual_hash" ]; then
            echo -e "${GREEN}✓ $file_path${NC}"
        else
            echo -e "${RED}✗ $file_path${NC}"
            if [ "$VERBOSE" = true ]; then
                echo -e "  期望: $expected_hash"
                echo -e "  实际: $actual_hash"
            fi
            errors=$((errors + 1))
        fi
    done < "$hash_file"
    
    echo ""
    echo "======================================"
    echo "验证结果:"
    echo "  总文件数: $total"
    echo -e "  成功: ${GREEN}$((total - errors))${NC}"
    echo -e "  失败: ${RED}$errors${NC}"
    
    if [ "$errors" -eq 0 ]; then
        echo -e "${GREEN}所有文件验证通过！${NC}"
        return 0
    else
        echo -e "${RED}有 $errors 个文件验证失败！${NC}"
        return 1
    fi
}

# 主函数
main() {
    parse_args "$@"
    check_args
    
    # 验证模式
    if [ "$VERIFY_MODE" = true ]; then
        verify_hashes "$VERIFY_FILE" "$TARGET"
        exit $?
    fi
    
    # 计算模式
    echo "======================================"
    echo "          哈希计算"
    echo "======================================"
    echo "目标: $TARGET"
    echo "算法: $ALGORITHM"
    echo "递归: $RECURSIVE"
    
    if [ -n "$OUTPUT_FILE" ]; then
        echo "输出文件: $OUTPUT_FILE"
        # 清空输出文件
        > "$OUTPUT_FILE"
    fi
    
    echo ""
    
    # 处理目标
    if [ -f "$TARGET" ]; then
        process_file "$TARGET" "$(basename "$TARGET")"
    elif [ -d "$TARGET" ]; then
        process_directory "$TARGET" "$TARGET"
    fi
    
    echo ""
    echo "======================================"
    echo -e "${GREEN}哈希计算完成！${NC}"
    
    if [ -n "$OUTPUT_FILE" ]; then
        echo "结果已保存到: $OUTPUT_FILE"
    fi
}

# 执行主函数
main "$@"