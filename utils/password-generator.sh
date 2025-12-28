#!/bin/bash

# 密码生成器
# 功能：生成安全的随机密码
# 使用方法：./password-generator.sh [长度] [选项]

set -euo pipefail

# 默认参数
LENGTH=12
USE_UPPERCASE=true
USE_LOWERCASE=true
USE_NUMBERS=true
USE_SYMBOLS=true
AMBIGUOUS=false
COUNT=1
COPY_TO_CLIPBOARD=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "密码生成器使用说明:"
    echo "用法: $0 [长度] [选项]"
    echo ""
    echo "参数:"
    echo "  长度                密码长度（默认: 12）"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -c, --count NUM     生成密码数量（默认: 1）"
    echo "  -u, --uppercase     包含大写字母（默认启用）"
    echo "  -l, --lowercase     包含小写字母（默认启用）"
    echo "  -n, --numbers       包含数字（默认启用）"
    echo "  -s, --symbols       包含特殊字符（默认启用）"
    echo "  -a, --ambiguous     允许歧义字符（0O, 1lI等）"
    echo "  --no-uppercase     不包含大写字母"
    echo "  --no-lowercase     不包含小写字母"
    echo "  --no-numbers       不包含数字"
    echo "  --no-symbols       不包含特殊字符"
    echo "  --clipboard        复制到剪贴板"
    echo ""
    echo "示例:"
    echo "  $0 16 -c 5         # 生成5个16位密码"
    echo "  $0 20 --no-symbols # 生成20位不含特殊字符的密码"
    echo "  $0 8 --clipboard   # 生成8位密码并复制到剪贴板"
}

# 解析命令行参数
parse_args() {
    LENGTH="${1:-12}"
    shift 2>/dev/null || true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--count)
                COUNT="$2"
                shift 2
                ;;
            -u|--uppercase)
                USE_UPPERCASE=true
                shift
                ;;
            -l|--lowercase)
                USE_LOWERCASE=true
                shift
                ;;
            -n|--numbers)
                USE_NUMBERS=true
                shift
                ;;
            -s|--symbols)
                USE_SYMBOLS=true
                shift
                ;;
            -a|--ambiguous)
                AMBIGUOUS=true
                shift
                ;;
            --no-uppercase)
                USE_UPPERCASE=false
                shift
                ;;
            --no-lowercase)
                USE_LOWERCASE=false
                shift
                ;;
            --no-numbers)
                USE_NUMBERS=false
                shift
                ;;
            --no-symbols)
                USE_SYMBOLS=false
                shift
                ;;
            --clipboard)
                COPY_TO_CLIPBOARD=true
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
    # 检查长度是否为数字
    if ! [[ "$LENGTH" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 密码长度必须是数字${NC}"
        exit 1
    fi
    
    # 检查长度范围
    if [ "$LENGTH" -lt 4 ] || [ "$LENGTH" -gt 128 ]; then
        echo -e "${RED}错误: 密码长度应在4-128之间${NC}"
        exit 1
    fi
    
    # 检查数量是否为数字
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: 密码数量必须是数字${NC}"
        exit 1
    fi
    
    # 检查数量范围
    if [ "$COUNT" -lt 1 ] || [ "$COUNT" -gt 100 ]; then
        echo -e "${RED}错误: 密码数量应在1-100之间${NC}"
        exit 1
    fi
    
    # 检查是否至少有一种字符类型
    if [ "$USE_UPPERCASE" = false ] && [ "$USE_LOWERCASE" = false ] && \
       [ "$USE_NUMBERS" = false ] && [ "$USE_SYMBOLS" = false ]; then
        echo -e "${RED}错误: 必须至少选择一种字符类型${NC}"
        exit 1
    fi
    
    # 检查剪贴板功能
    if [ "$COPY_TO_CLIPBOARD" = true ]; then
        if command -v xclip >/dev/null 2>&1; then
            CLIPBOARD_CMD="xclip -selection clipboard"
        elif command -v pbcopy >/dev/null 2>&1; then
            CLIPBOARD_CMD="pbcopy"
        elif command -v clip.exe >/dev/null 2>&1; then
            CLIPBOARD_CMD="clip.exe"
        else
            echo -e "${YELLOW}警告: 未找到剪贴板工具，将禁用复制功能${NC}"
            COPY_TO_CLIPBOARD=false
        fi
    fi
}

# 生成字符集
generate_charset() {
    local charset=""
    
    if [ "$USE_UPPERCASE" = true ]; then
        if [ "$AMBIGUOUS" = true ]; then
            charset="${charset}ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        else
            charset="${charset}ABCDEFGHJKLMNPQRSTUVWXYZ"  # 排除 I, O
        fi
    fi
    
    if [ "$USE_LOWERCASE" = true ]; then
        if [ "$AMBIGUOUS" = true ]; then
            charset="${charset}abcdefghijklmnopqrstuvwxyz"
        else
            charset="${charset}abcdefghjkmnpqrstuvwxyz"  # 排除 i, l, o
        fi
    fi
    
    if [ "$USE_NUMBERS" = true ]; then
        if [ "$AMBIGUOUS" = true ]; then
            charset="${charset}0123456789"
        else
            charset="${charset}23456789"  # 排除 0, 1
        fi
    fi
    
    if [ "$USE_SYMBOLS" = true ]; then
        charset="${charset}!@#$%^&*()_+-=[]{}|;:,.<>?"
    fi
    
    echo "$charset"
}

# 生成密码
generate_password() {
    local length="$1"
    local charset="$2"
    local password=""
    
    # 使用/dev/urandom生成随机密码
    if [ -f /dev/urandom ]; then
        password=$(tr -dc "$charset" < /dev/urandom | head -c "$length")
    else
        # 备用方法
        for i in $(seq 1 "$length"); do
            local random_index=$((RANDOM % ${#charset}))
            password="${password}${charset:$random_index:1}"
        done
    fi
    
    echo "$password"
}

# 检查密码强度
check_password_strength() {
    local password="$1"
    local strength=0
    local feedback=()
    
    # 长度检查
    if [ ${#password} -ge 8 ]; then
        strength=$((strength + 1))
    else
        feedback+=("密码长度少于8位")
    fi
    
    if [ ${#password} -ge 12 ]; then
        strength=$((strength + 1))
    fi
    
    if [ ${#password} -ge 16 ]; then
        strength=$((strength + 1))
    fi
    
    # 字符类型检查
    if [[ "$password" =~ [A-Z] ]]; then
        strength=$((strength + 1))
    else
        feedback+=("缺少大写字母")
    fi
    
    if [[ "$password" =~ [a-z] ]]; then
        strength=$((strength + 1))
    else
        feedback+=("缺少小写字母")
    fi
    
    if [[ "$password" =~ [0-9] ]]; then
        strength=$((strength + 1))
    else
        feedback+=("缺少数字")
    fi
    
    if [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        strength=$((strength + 1))
    else
        feedback+=("缺少特殊字符")
    fi
    
    # 输出强度评级
    case $strength in
        0|1|2)
            echo -e "  强度: ${RED}弱${NC}"
            ;;
        3|4)
            echo -e "  强度: ${YELLOW}中等${NC}"
            ;;
        5|6)
            echo -e "  强度: ${BLUE}强${NC}"
            ;;
        7|8)
            echo -e "  强度: ${GREEN}非常强${NC}"
            ;;
    esac
    
    # 输出反馈
    if [ ${#feedback[@]} -gt 0 ]; then
        echo -e "  ${YELLOW}建议:${NC}"
        for suggestion in "${feedback[@]}"; do
            echo -e "    - $suggestion"
        done
    fi
}

# 复制到剪贴板
copy_to_clipboard() {
    local text="$1"
    
    if [ "$COPY_TO_CLIPBOARD" = true ]; then
        echo "$text" | $CLIPBOARD_CMD
        echo -e "  ${GREEN}已复制到剪贴板${NC}"
    fi
}

# 主函数
main() {
    parse_args "$@"
    check_args
    
    # 生成字符集
    charset=$(generate_charset)
    
    if [ -z "$charset" ]; then
        echo -e "${RED}错误: 字符集为空${NC}"
        exit 1
    fi
    
    echo "======================================"
    echo "          密码生成器"
    echo "======================================"
    echo "密码长度: $LENGTH"
    echo "字符集: ${#charset}个字符"
    echo "生成数量: $COUNT"
    echo "包含大写字母: $USE_UPPERCASE"
    echo "包含小写字母: $USE_LOWERCASE"
    echo "包含数字: $USE_NUMBERS"
    echo "包含特殊字符: $USE_SYMBOLS"
    echo "允许歧义字符: $AMBIGUOUS"
    echo ""
    
    # 生成密码
    for i in $(seq 1 "$COUNT"); do
        if [ "$COUNT" -gt 1 ]; then
            echo -e "${BLUE}密码 $i:${NC}"
        fi
        
        password=$(generate_password "$LENGTH" "$charset")
        echo -e "  ${GREEN}$password${NC}"
        
        # 检查密码强度
        check_password_strength "$password"
        
        # 复制到剪贴板（只复制第一个）
        if [ "$i" -eq 1 ] && [ "$COPY_TO_CLIPBOARD" = true ]; then
            copy_to_clipboard "$password"
        fi
        
        if [ "$COUNT" -gt 1 ]; then
            echo ""
        fi
    done
    
    echo "======================================"
}

# 执行主函数
main "$@"
