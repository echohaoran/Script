#!/bin/bash

# 进程监控脚本
# 功能：监控系统进程，检测异常进程和资源使用情况
# 使用方法：./process-monitor.sh [选项]

set -euo pipefail

# 默认参数
INTERVAL=10
ALERT_CPU=80
ALERT_MEM=80
LOG_FILE="/tmp/process-monitor-$(date +%Y%m%d_%H%M%S).log"
DAEMON_MODE=false
VERBOSE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "进程监控脚本使用说明:"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -i, --interval SEC  设置监控间隔（秒，默认: 10）"
    echo "  -c, --cpu-percent   CPU使用率告警阈值（默认: 80）"
    echo "  -m, --mem-percent   内存使用率告警阈值（默认: 80）"
    echo "  -d, --daemon        后台守护进程模式"
    echo "  -v, --verbose       详细输出"
    echo ""
    echo "示例:"
    echo "  $0                  # 使用默认设置监控一次"
    echo "  $0 -i 30 -c 90 -m 90  # 30秒间隔，CPU和内存阈值90%"
    echo "  $0 -d               # 后台守护进程模式"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interval)
                INTERVAL="$2"
                shift 2
                ;;
            -c|--cpu-percent)
                ALERT_CPU="$2"
                shift 2
                ;;
            -m|--mem-percent)
                ALERT_MEM="$2"
                shift 2
                ;;
            -d|--daemon)
                DAEMON_MODE=true
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

# 创建日志文件
setup_logging() {
    touch "$LOG_FILE"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    echo "======================================"
    echo "          进程监控工具"
    echo "======================================"
    echo "开始时间: $(date)"
    echo "监控间隔: ${INTERVAL}秒"
    echo "CPU告警阈值: ${ALERT_CPU}%"
    echo "内存告警阈值: ${ALERT_MEM}%"
    echo "守护进程模式: $DAEMON_MODE"
    echo "详细输出: $VERBOSE"
    echo ""
}

# 获取CPU使用率
get_cpu_usage() {
    local pid=$1
    local cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
    echo "${cpu_usage%.*}"
}

# 获取内存使用率
get_mem_usage() {
    local pid=$1
    local mem_usage=$(ps -p "$pid" -o %mem --no-headers 2>/dev/null | tr -d ' ' || echo "0")
    echo "${mem_usage%.*}"
}

# 获取进程信息
get_process_info() {
    local pid=$1
    local info=$(ps -p "$pid" -o pid,ppid,user,cmd --no-headers 2>/dev/null || echo "")
    echo "$info"
}

# 检查高CPU使用率进程
check_high_cpu() {
    echo -e "${BLUE}==== 高CPU使用率进程 (> ${ALERT_CPU}%) ====${NC}"
    
    local found=false
    ps aux --sort=-%cpu | awk -v threshold="$ALERT_CPU" 'NR>1 && $3 >= threshold {print $0}' | while read line; do
        if [ -n "$line" ]; then
            found=true
            local pid=$(echo "$line" | awk '{print $2}')
            local cpu=$(echo "$line" | awk '{print int($3)}')
            local mem=$(echo "$line" | awk '{print int($4)}')
            local user=$(echo "$line" | awk '{print $1}')
            local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
            
            echo -e "  ${RED}PID $pid${NC} - CPU: ${cpu}% - 内存: ${mem}% - 用户: $user"
            echo -e "    命令: $cmd"
            
            if [ "$VERBOSE" = true ]; then
                local process_info=$(get_process_info "$pid")
                echo -e "    详细信息: $process_info"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "  ${GREEN}无高CPU使用率进程${NC}"
    fi
    
    echo ""
}

# 检查高内存使用率进程
check_high_memory() {
    echo -e "${BLUE}==== 高内存使用率进程 (> ${ALERT_MEM}%) ====${NC}"
    
    local found=false
    ps aux --sort=-%mem | awk -v threshold="$ALERT_MEM" 'NR>1 && $4 >= threshold {print $0}' | while read line; do
        if [ -n "$line" ]; then
            found=true
            local pid=$(echo "$line" | awk '{print $2}')
            local cpu=$(echo "$line" | awk '{print int($3)}')
            local mem=$(echo "$line" | awk '{print int($4)}')
            local user=$(echo "$line" | awk '{print $1}')
            local cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
            
            echo -e "  ${RED}PID $pid${NC} - CPU: ${cpu}% - 内存: ${mem}% - 用户: $user"
            echo -e "    命令: $cmd"
            
            if [ "$VERBOSE" = true ]; then
                local process_info=$(get_process_info "$pid")
                echo -e "    详细信息: $process_info"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "  ${GREEN}无高内存使用率进程${NC}"
    fi
    
    echo ""
}

# 检查僵尸进程
check_zombie_processes() {
    echo -e "${BLUE}==== 僵尸进程 ====${NC}"
    
    local zombie_count=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
    
    if [ "$zombie_count" -gt 0 ]; then
        echo -e "  ${RED}发现 $zombie_count 个僵尸进程${NC}"
        if [ "$VERBOSE" = true ]; then
            ps aux | awk '$8 ~ /^Z/ {print "    PID: "$2" PPID: "$3" CMD: "$11}'
        fi
    else
        echo -e "  ${GREEN}无僵尸进程${NC}"
    fi
    
    echo ""
}

# 检查系统负载
check_system_load() {
    echo -e "${BLUE}==== 系统负载 ====${NC}"
    
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
    local cpu_count=$(nproc)
    
    echo "当前负载: $load_avg"
    echo "CPU核心数: $cpu_count"
    
    # 检查1分钟负载
    local load_1=$(echo "$load_avg" | cut -d, -f1 | tr -d ' ')
    local load_threshold=$((cpu_count * 2))
    
    if (( $(echo "$load_1 > $load_threshold" | bc -l) )); then
        echo -e "  ${RED}系统负载过高！${NC}"
    else
        echo -e "  ${GREEN}系统负载正常${NC}"
    fi
    
    echo ""
}

# 检查进程数量
check_process_count() {
    echo -e "${BLUE}==== 进程统计 ====${NC}"
    
    local total_processes=$(ps aux | wc -l)
    local running_processes=$(ps aux | awk '$8 ~ /^R/ {count++} END {print count+0}')
    local sleeping_processes=$(ps aux | awk '$8 ~ /^S/ {count++} END {print count+0}')
    
    echo "总进程数: $total_processes"
    echo "运行中: $running_processes"
    echo "休眠中: $sleeping_processes"
    
    # 按用户统计
    echo ""
    echo "按用户统计:"
    ps aux --no-headers | awk '{users[$1]++} END {for (user in users) print "  " user ": " users[user]}' | sort -k2 -nr
    
    echo ""
}

# 监控循环
monitor_loop() {
    echo -e "${GREEN}开始监控循环... (按Ctrl+C停止)${NC}"
    echo ""
    
    while true; do
        echo "监控时间: $(date)"
        echo "----------------------------------------"
        
        check_system_load
        check_high_cpu
        check_high_memory
        check_zombie_processes
        check_process_count
        
        echo "========================================"
        echo "下次检查时间: $(date -d "+$INTERVAL seconds")"
        echo ""
        
        sleep "$INTERVAL"
    done
}

# 单次监控
single_monitor() {
    echo -e "${GREEN}执行单次进程监控...${NC}"
    echo ""
    
    check_system_load
    check_high_cpu
    check_high_memory
    check_zombie_processes
    check_process_count
}

# 主函数
main() {
    parse_args "$@"
    setup_logging
    
    if [ "$DAEMON_MODE" = true ]; then
        monitor_loop
    else
        single_monitor
    fi
    
    echo "======================================"
    echo -e "${GREEN}进程监控完成！${NC}"
    echo "结束时间: $(date)"
    echo "日志文件: $LOG_FILE"
}

# 信号处理
trap 'echo -e "\n${YELLOW}收到中断信号，正在退出...${NC}"; exit 0' INT TERM

# 执行主函数
main "$@"