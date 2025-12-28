#!/bin/bash

# 网络诊断脚本
# 功能：诊断网络连接问题，包括连通性、DNS、速度测试等
# 使用方法：./network-diag.sh [选项]

set -euo pipefail

# 默认参数
TARGET_HOST="8.8.8.8"
DNS_SERVER="8.8.8.8"
PORT=80
VERBOSE=false
LOG_FILE="/tmp/network-diag-$(date +%Y%m%d_%H%M%S).log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "网络诊断脚本使用说明:"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -t, --target HOST   设置目标主机（默认: 8.8.8.8）"
    echo "  -d, --dns SERVER    设置DNS服务器（默认: 8.8.8.8）"
    echo "  -p, --port PORT     设置测试端口（默认: 80）"
    echo "  -v, --verbose       详细输出"
    echo ""
    echo "示例:"
    echo "  $0                  # 使用默认设置"
    echo "  $0 -t baidu.com -p 443  # 测试百度HTTPS连接"
    echo "  $0 -v               # 详细模式"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--target)
                TARGET_HOST="$2"
                shift 2
                ;;
            -d|--dns)
                DNS_SERVER="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
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
    echo "          网络诊断工具"
    echo "======================================"
    echo "开始时间: $(date)"
    echo "目标主机: $TARGET_HOST"
    echo "DNS服务器: $DNS_SERVER"
    echo "测试端口: $PORT"
    echo "详细输出: $VERBOSE"
    echo ""
}

# 检查网络接口
check_interfaces() {
    echo -e "${BLUE}==== 网络接口状态 ====${NC}"
    
    if command -v ip >/dev/null 2>&1; then
        ip addr show | grep -E "^[0-9]+:|inet " | while read line; do
            if [[ $line =~ ^[0-9]+: ]]; then
                interface=$(echo "$line" | cut -d: -f2 | tr -d ' ')
                status=$(echo "$line" | grep -o "UP\|DOWN" || echo "UNKNOWN")
                echo -e "  接口: ${GREEN}$interface${NC} (${status})"
            elif [[ $line =~ inet ]]; then
                ip=$(echo "$line" | awk '{print $2}')
                echo -e "    IP地址: $ip"
            fi
        done
    else
        ifconfig 2>/dev/null | grep -E "^[a-zA-Z]" | while read line; do
            interface=$(echo "$line" | cut -d: -f1 | tr -d ' ')
            status=$(echo "$line" | grep -o "UP\|DOWN" || echo "UNKNOWN")
            echo -e "  接口: ${GREEN}$interface${NC} (${status})"
        done
    fi
    echo ""
}

# 检查路由表
check_routing() {
    echo -e "${BLUE}==== 路由表 ====${NC}"
    
    if command -v ip >/dev/null 2>&1; then
        echo "默认路由:"
        ip route show default 2>/dev/null || echo -e "  ${RED}未找到默认路由${NC}"
    else
        echo "默认路由:"
        route -n 2>/dev/null | grep "^0.0.0.0" || echo -e "  ${RED}未找到默认路由${NC}"
    fi
    echo ""
}

# 检查DNS配置
check_dns() {
    echo -e "${BLUE}==== DNS配置 ====${NC}"
    
    if [ -f /etc/resolv.conf ]; then
        echo "DNS服务器:"
        grep "^nameserver" /etc/resolv.conf | while read line; do
            server=$(echo "$line" | cut -d' ' -f2)
            echo -e "  $server"
        done
        
        echo "搜索域:"
        grep "^search" /etc/resolv.conf | cut -d' ' -f2- || echo "  无搜索域"
    else
        echo -e "  ${RED}未找到resolv.conf文件${NC}"
    fi
    echo ""
}

# 测试连通性
test_connectivity() {
    echo -e "${BLUE}==== 连通性测试 ====${NC}"
    
    # Ping测试
    echo -n "Ping $TARGET_HOST: "
    if ping -c 4 -W 5 "$TARGET_HOST" >/dev/null 2>&1; then
        echo -e "${GREEN}成功${NC}"
        if [ "$VERBOSE" = true ]; then
            ping -c 4 -W 5 "$TARGET_HOST" 2>&1 | tail -1
        fi
    else
        echo -e "${RED}失败${NC}"
    fi
    
    # 网关连通性
    local gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
    if [ -n "$gateway" ]; then
        echo -n "Ping 网关 $gateway: "
        if ping -c 2 -W 3 "$gateway" >/dev/null 2>&1; then
            echo -e "${GREEN}成功${NC}"
        else
            echo -e "${RED}失败${NC}"
        fi
    fi
    
    # 本地连通性
    echo -n "Ping 本地回环: "
    if ping -c 2 -W 3 127.0.0.1 >/dev/null 2>&1; then
        echo -e "${GREEN}成功${NC}"
    else
        echo -e "${RED}失败${NC}"
    fi
    
    echo ""
}

# 测试DNS解析
test_dns() {
    echo -e "${BLUE}==== DNS解析测试 ====${NC}"
    
    # 测试DNS服务器
    echo -n "DNS服务器 $DNS_SERVER: "
    if ping -c 2 -W 3 "$DNS_SERVER" >/dev/null 2>&1; then
        echo -e "${GREEN}可达${NC}"
    else
        echo -e "${RED}不可达${NC}"
    fi
    
    # 解析测试
    local test_domains=("google.com" "baidu.com" "github.com")
    for domain in "${test_domains[@]}"; do
        echo -n "解析 $domain: "
        if nslookup "$domain" >/dev/null 2>&1 || dig "$domain" >/dev/null 2>&1; then
            echo -e "${GREEN}成功${NC}"
            if [ "$VERBOSE" = true ]; then
                nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print "    " $2}' || \
                dig "$domain" +short 2>/dev/null | head -n1 | awk '{print "    " $1}'
            fi
        else
            echo -e "${RED}失败${NC}"
        fi
    done
    
    echo ""
}

# 测试端口连通性
test_port() {
    echo -e "${BLUE}==== 端口连通性测试 ====${NC}"
    
    echo -n "$TARGET_HOST:$PORT: "
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w5 "$TARGET_HOST" "$PORT" 2>/dev/null; then
            echo -e "${GREEN}开放${NC}"
        else
            echo -e "${RED}关闭或不可达${NC}"
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout 5 telnet "$TARGET_HOST" "$PORT" </dev/null >/dev/null 2>&1; then
            echo -e "${GREEN}开放${NC}"
        else
            echo -e "${RED}关闭或不可达${NC}"
        fi
    else
        echo -e "${YELLOW}无法测试（缺少nc或telnet）${NC}"
    fi
    
    echo ""
}

# 网络速度测试
test_speed() {
    echo -e "${BLUE}==== 网络速度测试 ====${NC}"
    
    if command -v curl >/dev/null 2>&1; then
        echo -n "下载速度测试: "
        local speed_result=$(curl -o /dev/null -s -w "%{speed_download}" -m 10 "http://speedtest.wdc01.softlayer.com/downloads/test10.zip" 2>/dev/null || echo "0")
        if [ "$speed_result" != "0" ]; then
            local speed_kbps=$(echo "$speed_result" | awk '{printf "%.2f", $1/1024}')
            echo -e "${GREEN}$speed_kbps KB/s${NC}"
        else
            echo -e "${RED}测试失败${NC}"
        fi
    else
        echo -e "${YELLOW}无法测试（缺少curl）${NC}"
    fi
    
    echo ""
}

# 跟踪路由
trace_route() {
    echo -e "${BLUE}==== 路由跟踪 ====${NC}"
    
    if command -v traceroute >/dev/null 2>&1; then
        echo "到 $TARGET_HOST 的路由:"
        traceroute -m 10 -w 2 "$TARGET_HOST" 2>/dev/null | head -n 10
    elif command -v tracepath >/dev/null 2>&1; then
        echo "到 $TARGET_HOST 的路由:"
        tracepath "$TARGET_HOST" 2>/dev/null | head -n 10
    else
        echo -e "${YELLOW}无法跟踪路由（缺少traceroute或tracepath）${NC}"
    fi
    
    echo ""
}

# 主函数
main() {
    parse_args "$@"
    setup_logging
    
    check_interfaces
    check_routing
    check_dns
    test_connectivity
    test_dns
    test_port
    test_speed
    trace_route
    
    echo "======================================"
    echo -e "${GREEN}网络诊断完成！${NC}"
    echo "结束时间: $(date)"
    echo "日志文件: $LOG_FILE"
}

# 执行主函数
main "$@"