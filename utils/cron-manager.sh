#!/bin/bash

# 定时任务管理工具
# 功能：管理系统定时任务（cron）
# 使用方法：./cron-manager.sh [命令] [选项]

set -euo pipefail

# 默认参数
COMMAND=""
CRON_FILE=""
USER_NAME=""
BACKUP_DIR="$HOME/.cron-backups"
VERBOSE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "定时任务管理工具使用说明:"
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  list                列出当前用户的定时任务"
    echo "  add                 添加定时任务"
    echo "  remove              删除定时任务"
    echo "  edit                编辑定时任务"
    echo "  backup              备份定时任务"
    echo "  restore             恢复定时任务"
    echo "  enable              启用定时任务"
    echo "  disable             禁用定时任务"
    echo "  test                测试定时任务"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -f, --file FILE     指定cron文件"
    echo "  -u, --user USER     指定用户（默认: 当前用户）"
    echo "  -b, --backup DIR    备份目录（默认: ~/.cron-backups）"
    echo "  -v, --verbose       详细输出"
    echo ""
    echo "add命令选项:"
    echo "  -m, --minute MIN    分钟 (0-59)"
    echo "  -h, --hour HOUR     小时 (0-23)"
    echo "  -d, --day DAY       日期 (1-31)"
    echo "  -M, --month MONTH   月份 (1-12)"
    echo "  -w, --weekday DAY   星期 (0-7, 0和7都表示周日)"
    echo "  -c, --command CMD   要执行的命令"
    echo "  -n, --comment DESC  任务描述"
    echo ""
    echo "示例:"
    echo "  $0 list                           # 列出定时任务"
    echo "  $0 add -m 0 -h 2 -c \"/path/to/script.sh\"  # 每天凌晨2点执行"
    echo "  $0 add -c \"/path/to/backup.sh\" -n \"备份任务\"  # 使用默认时间"
    echo "  $0 backup                          # 备份定时任务"
    echo "  $0 restore -f backup-20231201.cron  # 恢复定时任务"
}

# 解析命令行参数
parse_args() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    COMMAND="$1"
    shift
    
    # 通用选项
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--file)
                CRON_FILE="$2"
                shift 2
                ;;
            -u|--user)
                USER_NAME="$2"
                shift 2
                ;;
            -b|--backup)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            # add命令选项
            -m|--minute)
                MINUTE="$2"
                shift 2
                ;;
            -H|--hour)
                HOUR="$2"
                shift 2
                ;;
            -d|--day)
                DAY="$2"
                shift 2
                ;;
            -M|--month)
                MONTH="$2"
                shift 2
                ;;
            -w|--weekday)
                WEEKDAY="$2"
                shift 2
                ;;
            -c|--command)
                CRON_COMMAND="$2"
                shift 2
                ;;
            -n|--comment)
                COMMENT="$2"
                shift 2
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置默认用户
    if [ -z "$USER_NAME" ]; then
        USER_NAME=$(whoami)
    fi
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
}

# 检查参数
check_args() {
    # 检查命令
    local valid_commands=("list" "add" "remove" "edit" "backup" "restore" "enable" "disable" "test")
    local found=false
    
    for cmd in "${valid_commands[@]}"; do
        if [ "$COMMAND" = "$cmd" ]; then
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "${RED}错误: 不支持的命令: $COMMAND${NC}"
        exit 1
    fi
    
    # 检查add命令参数
    if [ "$COMMAND" = "add" ]; then
        if [ -z "${CRON_COMMAND:-}" ]; then
            echo -e "${RED}错误: add命令需要指定 -c/--command 参数${NC}"
            exit 1
        fi
    fi
    
    # 检查restore命令参数
    if [ "$COMMAND" = "restore" ]; then
        if [ -z "$CRON_FILE" ]; then
            echo -e "${RED}错误: restore命令需要指定 -f/--file 参数${NC}"
            exit 1
        fi
        
        if [ ! -f "$CRON_FILE" ]; then
            echo -e "${RED}错误: 备份文件不存在: $CRON_FILE${NC}"
            exit 1
        fi
    fi
}

# 获取当前用户的定时任务
get_crontab() {
    local user="$1"
    
    if [ "$user" = "$(whoami)" ]; then
        crontab -l 2>/dev/null || echo ""
    else
        sudo crontab -u "$user" -l 2>/dev/null || echo ""
    fi
}

# 列出定时任务
list_crontab() {
    local user="$1"
    
    echo "======================================"
    echo "        定时任务列表"
    echo "======================================"
    echo "用户: $user"
    echo ""
    
    local crontab_content
    crontab_content=$(get_crontab "$user")
    
    if [ -z "$crontab_content" ]; then
        echo -e "${YELLOW}当前没有定时任务${NC}"
        return
    fi
    
    echo "定时任务:"
    echo "$crontab_content" | nl -b a
    
    # 统计信息
    local task_count
    task_count=$(echo "$crontab_content" | grep -v '^#' | grep -v '^$' | wc -l)
    echo ""
    echo "任务数量: $task_count"
}

# 添加定时任务
add_crontab() {
    local user="$1"
    local minute="${MINUTE:-*}"
    local hour="${HOUR:-*}"
    local day="${DAY:-*}"
    local month="${MONTH:-*}"
    local weekday="${WEEKDAY:-*}"
    local command="$CRON_COMMAND"
    local comment="${COMMENT:-}"
    
    # 验证时间参数
    if ! validate_time_field "$minute" 0 59; then
        echo -e "${RED}错误: 分钟参数无效: $minute${NC}"
        exit 1
    fi
    
    if ! validate_time_field "$hour" 0 23; then
        echo -e "${RED}错误: 小时参数无效: $hour${NC}"
        exit 1
    fi
    
    if ! validate_time_field "$day" 1 31; then
        echo -e "${RED}错误: 日期参数无效: $day${NC}"
        exit 1
    fi
    
    if ! validate_time_field "$month" 1 12; then
        echo -e "${RED}错误: 月份参数无效: $month${NC}"
        exit 1
    fi
    
    if ! validate_time_field "$weekday" 0 7; then
        echo -e "${RED}错误: 星期参数无效: $weekday${NC}"
        exit 1
    fi
    
    echo "======================================"
    echo "        添加定时任务"
    echo "======================================"
    echo "用户: $user"
    echo "时间: $minute $hour $day $month $weekday"
    echo "命令: $command"
    echo "描述: $comment"
    echo ""
    
    # 构建cron条目
    local cron_entry="$minute $hour $day $month $weekday $command"
    
    if [ -n "$comment" ]; then
        cron_entry="# $comment\n$cron_entry"
    fi
    
    # 获取当前crontab
    local current_crontab
    current_crontab=$(get_crontab "$user")
    
    # 添加新任务
    local new_crontab
    if [ -n "$current_crontab" ]; then
        new_crontab="$current_crontab\n$cron_entry"
    else
        new_crontab="$cron_entry"
    fi
    
    # 安装新的crontab
    if echo -e "$new_crontab" | crontab -; then
        echo -e "${GREEN}定时任务添加成功${NC}"
    else
        echo -e "${RED}定时任务添加失败${NC}"
        exit 1
    fi
}

# 验证时间字段
validate_time_field() {
    local field="$1"
    local min="$2"
    local max="$3"
    
    # 允许通配符
    if [ "$field" = "*" ]; then
        return 0
    fi
    
    # 允许列表 (1,2,3)
    if [[ "$field" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        local IFS=','
        for num in $field; do
            if [ "$num" -lt "$min" ] || [ "$num" -gt "$max" ]; then
                return 1
            fi
        done
        return 0
    fi
    
    # 允许范围 (1-5)
    if [[ "$field" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=$(echo "$field" | cut -d'-' -f1)
        local end=$(echo "$field" | cut -d'-' -f2)
        
        if [ "$start" -lt "$min" ] || [ "$start" -gt "$max" ] || \
           [ "$end" -lt "$min" ] || [ "$end" -gt "$max" ] || \
           [ "$start" -gt "$end" ]; then
            return 1
        fi
        return 0
    fi
    
    # 允许步长 (*/5)
    if [[ "$field" =~ ^\*/[0-9]+$ ]]; then
        local step=$(echo "$field" | cut -d'/' -f2)
        if [ "$step" -eq 0 ]; then
            return 1
        fi
        return 0
    fi
    
    # 允许单个数字
    if [[ "$field" =~ ^[0-9]+$ ]]; then
        if [ "$field" -lt "$min" ] || [ "$field" -gt "$max" ]; then
            return 1
        fi
        return 0
    fi
    
    return 1
}

# 备份定时任务
backup_crontab() {
    local user="$1"
    local backup_file="$BACKUP_DIR/cron-$(date +%Y%m%d_%H%M%S).cron"
    
    echo "======================================"
    echo "        备份定时任务"
    echo "======================================"
    echo "用户: $user"
    echo "备份文件: $backup_file"
    echo ""
    
    local crontab_content
    crontab_content=$(get_crontab "$user")
    
    if [ -z "$crontab_content" ]; then
        echo -e "${YELLOW}当前没有定时任务，但仍然创建备份文件${NC}"
        echo "# 空的crontab文件" > "$backup_file"
    else
        echo "$crontab_content" > "$backup_file"
    fi
    
    echo -e "${GREEN}备份完成${NC}"
    echo "备份文件: $backup_file"
    
    # 显示备份文件列表
    echo ""
    echo "最近的备份文件:"
    ls -lt "$BACKUP_DIR"/*.cron 2>/dev/null | head -n 5
}

# 恢复定时任务
restore_crontab() {
    local user="$1"
    local backup_file="$CRON_FILE"
    
    echo "======================================"
    echo "        恢复定时任务"
    echo "======================================"
    echo "用户: $user"
    echo "备份文件: $backup_file"
    echo ""
    
    # 显示备份内容
    echo "备份内容预览:"
    head -n 10 "$backup_file"
    echo "..."
    
    # 确认恢复
    read -p "确定要恢复吗？(y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "取消恢复"
        exit 0
    fi
    
    # 先备份当前任务
    backup_crontab "$user"
    
    # 恢复任务
    if crontab "$backup_file"; then
        echo -e "${GREEN}恢复成功${NC}"
    else
        echo -e "${RED}恢复失败${NC}"
        exit 1
    fi
}

# 编辑定时任务
edit_crontab() {
    local user="$1"
    
    echo "======================================"
    echo "        编辑定时任务"
    echo "======================================"
    echo "用户: $user"
    echo ""
    
    # 先备份当前任务
    backup_crontab "$user"
    
    # 编辑crontab
    if [ "$user" = "$(whoami)" ]; then
        crontab -e
    else
        sudo crontab -u "$user" -e
    fi
    
    echo -e "${GREEN}编辑完成${NC}"
}

# 测试定时任务
test_crontab() {
    local user="$1"
    
    echo "======================================"
    echo "        测试定时任务"
    echo "======================================"
    echo "用户: $user"
    echo ""
    
    local crontab_content
    crontab_content=$(get_crontab "$user")
    
    if [ -z "$crontab_content" ]; then
        echo -e "${YELLOW}当前没有定时任务${NC}"
        return
    fi
    
    echo "测试定时任务语法..."
    
    # 创建临时文件
    local temp_file="/tmp/crontab_test_$$.tmp"
    echo "$crontab_content" > "$temp_file"
    
    # 测试语法
    if crontab "$temp_file" 2>/dev/null; then
        echo -e "${GREEN}语法检查通过${NC}"
    else
        echo -e "${RED}语法检查失败${NC}"
    fi
    
    # 清理临时文件
    rm -f "$temp_file"
    
    # 显示任务分析
    echo ""
    echo "任务分析:"
    echo "$crontab_content" | grep -v '^#' | grep -v '^$' | while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "  $line"
            
            # 解析时间字段
            local minute=$(echo "$line" | awk '{print $1}')
            local hour=$(echo "$line" | awk '{print $2}')
            local day=$(echo "$line" | awk '{print $3}')
            local month=$(echo "$line" | awk '{print $4}')
            local weekday=$(echo "$line" | awk '{print $5}')
            local command=$(echo "$line" | cut -d' ' -f6-)
            
            echo "    时间: $minute $hour $day $month $weekday"
            echo "    命令: $command"
            echo ""
        fi
    done
}

# 主函数
main() {
    parse_args "$@"
    check_args
    
    case "$COMMAND" in
        "list")
            list_crontab "$USER_NAME"
            ;;
        "add")
            add_crontab "$USER_NAME"
            ;;
        "remove")
            echo "删除功能待实现"
            ;;
        "edit")
            edit_crontab "$USER_NAME"
            ;;
        "backup")
            backup_crontab "$USER_NAME"
            ;;
        "restore")
            restore_crontab "$USER_NAME"
            ;;
        "enable")
            echo "启用功能待实现"
            ;;
        "disable")
            echo "禁用功能待实现"
            ;;
        "test")
            test_crontab "$USER_NAME"
            ;;
        *)
            echo -e "${RED}错误: 不支持的命令: $COMMAND${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo "======================================"
}

# 执行主函数
main "$@"
