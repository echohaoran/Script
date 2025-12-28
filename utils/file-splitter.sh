#!/bin/bash

# 文件分割与合并工具
# 功能：将大文件分割成小块，或将多个文件合并
# 使用方法：./file-splitter.sh [操作] [文件] [选项]

set -euo pipefail

# 默认参数
OPERATION=""
FILE=""
SIZE="100M"
PREFIX=""
OUTPUT_DIR=""
DELETE_AFTER=false
VERBOSE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "文件分割与合并工具使用说明:"
    echo "用法: $0 [操作] [文件] [选项]"
    echo ""
    echo "操作:"
    echo "  split              分割文件"
    echo "  merge              合并文件"
    echo ""
    echo "参数:"
    echo "  文件                目标文件"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -s, --size SIZE     分割大小（默认: 100M）"
    echo "  -p, --prefix PREFIX 分割文件前缀（默认: 文件名）"
    echo "  -o, --output DIR    输出目录（默认: 当前目录）"
    echo "  -d, --delete        合并后删除分割文件"
    echo "  -v, --verbose       详细输出"
    echo ""
    echo "大小格式:"
    echo "  K, KB              千字节"
    echo "  M, MB              兆字节"
    echo "  G, GB              吉字节"
    echo "  T, TB              太字节"
    echo ""
    echo "示例:"
    echo "  $0 split largefile.zip -s 50M"
    echo "  $0 merge largefile.zip"
    echo "  $0 split bigfile.iso -s 1G -o /tmp/splits"
    echo "  $0 merge bigfile.iso -d"
}

# 解析命令行参数
parse_args() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    OPERATION="$1"
    shift
    
    if [ $# -eq 0 ]; then
        echo -e "${RED}错误: 请指定文件${NC}"
        show_help
        exit 1
    fi
    
    FILE="$1"
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--size)
                SIZE="$2"
                shift 2
                ;;
            -p|--prefix)
                PREFIX="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -d|--delete)
                DELETE_AFTER=true
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
    # 检查操作
    if [ "$OPERATION" != "split" ] && [ "$OPERATION" != "merge" ]; then
        echo -e "${RED}错误: 不支持的操作: $OPERATION${NC}"
        show_help
        exit 1
    fi
    
    # 检查文件
    if [ -z "$FILE" ]; then
        echo -e "${RED}错误: 请指定文件${NC}"
        exit 1
    fi
    
    # 分割模式检查
    if [ "$OPERATION" = "split" ]; then
        if [ ! -f "$FILE" ]; then
            echo -e "${RED}错误: 文件不存在: $FILE${NC}"
            exit 1
        fi
        
        # 解析大小
        if ! parse_size "$SIZE"; then
            echo -e "${RED}错误: 无效的大小格式: $SIZE${NC}"
            exit 1
        fi
    fi
    
    # 合并模式检查
    if [ "$OPERATION" = "merge" ]; then
        # 设置默认前缀
        if [ -z "$PREFIX" ]; then
            PREFIX="$FILE"
        fi
        
        # 检查分割文件是否存在
        local first_file="${PREFIX}.aa"
        if [ ! -f "$first_file" ]; then
            echo -e "${RED}错误: 找不到分割文件: $first_file${NC}"
            exit 1
        fi
    fi
    
    # 设置默认前缀
    if [ -z "$PREFIX" ]; then
        PREFIX="$(basename "$FILE")"
    fi
    
    # 设置默认输出目录
    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$(dirname "$FILE")"
    fi
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
}

# 解析大小
parse_size() {
    local size_str="$1"
    
    # 移除空格
    size_str=$(echo "$size_str" | tr -d ' ')
    
    # 检查格式
    if [[ ! "$size_str" =~ ^[0-9]+[KMG]?B?$ ]]; then
        return 1
    fi
    
    # 提取数字和单位
    local number=$(echo "$size_str" | grep -o '[0-9]\+')
    local unit=$(echo "$size_str" | grep -o '[KMG]B\?$' || echo "B")
    
    # 转换为字节
    case "$unit" in
        B|b|"")
            SIZE_BYTES=$((number))
            ;;
        K|k|KB|kb)
            SIZE_BYTES=$((number * 1024))
            ;;
        M|m|MB|mb)
            SIZE_BYTES=$((number * 1024 * 1024))
            ;;
        G|g|GB|gb)
            SIZE_BYTES=$((number * 1024 * 1024 * 1024))
            ;;
        T|t|TB|tb)
            SIZE_BYTES=$((number * 1024 * 1024 * 1024 * 1024))
            ;;
        *)
            return 1
            ;;
    esac
    
    return 0
}

# 分割文件
split_file() {
    local file="$1"
    local size="$2"
    local prefix="$3"
    local output_dir="$4"
    
    echo "======================================"
    echo "          文件分割"
    echo "======================================"
    echo "源文件: $file"
    echo "分割大小: $size ($SIZE_BYTES 字节)"
    echo "前缀: $prefix"
    echo "输出目录: $output_dir"
    echo ""
    
    # 获取文件信息
    local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    local file_count=$((file_size / SIZE_BYTES + 1))
    
    echo "文件大小: $(format_size $file_size)"
    echo "预计分割为: $file_count 个文件"
    echo ""
    
    # 执行分割
    echo -e "${BLUE}开始分割...${NC}"
    
    local split_cmd="split -b $SIZE_BYTES -d -a 3 \"$file\" \"$output_dir/$prefix.\""
    
    if [ "$VERBOSE" = true ]; then
        echo "执行命令: $split_cmd"
    fi
    
    if eval "$split_cmd"; then
        # 重命名文件
        local index=0
        for part in "$output_dir/$prefix".*; do
            if [ -f "$part" ]; then
                local new_name=$(printf "%s.%s" "$prefix" "$(printf '%s' "$(basename "$part")" | tail -c 4)")
                mv "$part" "$output_dir/$new_name"
                
                if [ "$VERBOSE" = true ]; then
                    local part_size=$(stat -c%s "$output_dir/$new_name" 2>/dev/null || stat -f%z "$output_dir/$new_name" 2>/dev/null)
                    echo "  创建: $new_name ($(format_size $part_size))"
                fi
                
                index=$((index + 1))
            fi
        done
        
        echo ""
        echo -e "${GREEN}分割完成！${NC}"
        echo "共创建 $index 个文件"
        
        # 生成合并脚本
        generate_merge_script "$output_dir" "$prefix" "$file"
    else
        echo -e "${RED}分割失败！${NC}"
        exit 1
    fi
}

# 合并文件
merge_files() {
    local prefix="$1"
    local output_file="$2"
    local output_dir="$3"
    
    echo "======================================"
    echo "          文件合并"
    echo "======================================"
    echo "前缀: $prefix"
    echo "输出文件: $output_file"
    echo "输出目录: $output_dir"
    echo ""
    
    # 查找分割文件
    local split_files=()
    for file in "$output_dir/$prefix".*; do
        if [ -f "$file" ]; then
            split_files+=("$file")
        fi
    done
    
    # 按名称排序
    IFS=$'\n' split_files=($(sort <<<"${split_files[*]}"))
    unset IFS
    
    if [ ${#split_files[@]} -eq 0 ]; then
        echo -e "${RED}错误: 找不到分割文件${NC}"
        exit 1
    fi
    
    echo "找到 ${#split_files[@]} 个分割文件:"
    for file in "${split_files[@]}"; do
        local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        echo "  $(basename "$file") ($(format_size $file_size))"
    done
    echo ""
    
    # 计算总大小
    local total_size=0
    for file in "${split_files[@]}"; do
        local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        total_size=$((total_size + file_size))
    done
    
    echo "预计合并后大小: $(format_size $total_size)"
    echo ""
    
    # 执行合并
    echo -e "${BLUE}开始合并...${NC}"
    
    if [ "$VERBOSE" = true ]; then
        echo "合并命令: cat \"${split_files[@]}\" > \"$output_file\""
    fi
    
    if cat "${split_files[@]}" > "$output_file"; then
        echo ""
        echo -e "${GREEN}合并完成！${NC}"
        
        local merged_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null)
        echo "合并文件大小: $(format_size $merged_size)"
        
        # 验证完整性
        if [ "$total_size" = "$merged_size" ]; then
            echo -e "${GREEN}文件完整性验证通过${NC}"
        else
            echo -e "${YELLOW}警告: 文件大小不匹配，可能合并不完整${NC}"
        fi
        
        # 删除分割文件
        if [ "$DELETE_AFTER" = true ]; then
            echo ""
            echo -e "${BLUE}删除分割文件...${NC}"
            for file in "${split_files[@]}"; do
                rm "$file"
                if [ "$VERBOSE" = true ]; then
                    echo "  删除: $(basename "$file")"
                fi
            done
            echo -e "${GREEN}分割文件已删除${NC}"
        fi
    else
        echo -e "${RED}合并失败！${NC}"
        exit 1
    fi
}

# 生成合并脚本
generate_merge_script() {
    local output_dir="$1"
    local prefix="$2"
    local original_file="$3"
    local script_file="$output_dir/merge_$prefix.sh"
    
    cat > "$script_file" << EOF
#!/bin/bash
# 自动生成的合并脚本
# 用于合并 $prefix 分割文件

set -euo pipefail

echo "合并 $prefix 分割文件..."

# 查找分割文件
split_files=()
for file in "$output_dir/$prefix".*; do
    if [ -f "\$file" ]; then
        split_files+=("\$file")
    fi
done

# 按名称排序
IFS=\$'\\n' split_files=(\$(sort <<<"\${split_files[*]}"))
unset IFS

# 合并文件
if cat "\${split_files[@]}" > "$original_file"; then
    echo "合并完成: $original_file"
else
    echo "合并失败！"
    exit 1
fi
EOF
    
    chmod +x "$script_file"
    echo ""
    echo -e "${GREEN}合并脚本已生成: $script_file${NC}"
}

# 格式化大小
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $size -ge 1024 ] && [ $unit -lt 4 ]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "${size}${units[$unit]}"
}

# 主函数
main() {
    parse_args "$@"
    check_args
    
    case "$OPERATION" in
        "split")
            split_file "$FILE" "$SIZE" "$PREFIX" "$OUTPUT_DIR"
            ;;
        "merge")
            merge_files "$PREFIX" "$FILE" "$OUTPUT_DIR"
            ;;
        *)
            echo -e "${RED}错误: 不支持的操作: $OPERATION${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo "======================================"
}

# 执行主函数
main "$@"