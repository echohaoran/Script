#!/bin/bash

# macOS网络诊断脚本
# 功能：诊断和修复macOS网络连接问题
# 使用方法：./network-diag.sh [选项]

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/tmp/network-diag-$(date +%Y%m%d_%H%M%S).log"

# 创建日志文件
touch "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "       macOS网络诊断工具"
echo "======================================"
echo "开始时间: $(date)"
echo ""

# 显示帮助信息
show_help() {
    echo "macOS网络诊断脚本使用说明:"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -a, --all           执行所有诊断和修复"
    echo "  -c, --check         仅检查网络状态"
    echo "  -f, --fix           尝试修复网络问题"
    echo "  -s, --speed         测试网络速度"
    echo "  -d, --dns           诊断DNS问题"
    echo "  -r, --reset         重置网络设置"
    echo ""
    echo "示例:"
    echo "  $0 -a               # 执行所有诊断和修复"
    echo "  $0 -c               # 仅检查网络状态"
    echo "  $0 -f               # 尝试修复网络问题"
    echo "  $0 -s               # 测试网络速度"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                CHECK=true
                FIX=true
                SPEED=true
                DNS=true
                RESET=false
                shift
                ;;
            -c|--check)
                CHECK=true
                shift
                ;;
            -f|--fix)
                FIX=true
                shift
                ;;
            -s|--speed)
                SPEED=true
                shift
                ;;
            -d|--dns)
                DNS=true
                shift
                ;;
            -r|--reset)
                RESET=true
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定任何选项，默认执行检查
    if [ "${CHECK:-false}" != true ] && [ "${FIX:-false}" != true ] && \
       [ "${SPEED:-false}" != true ] && [ "${DNS:-false}" != true ] && \
       [ "${RESET:-false}" != true ]; then
        CHECK=true
    fi
}

# 检查网络接口状态
check_interfaces() {
    if [ "${CHECK:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 网络接口状态 ====${NC}"
    
    # 列出所有网络接口
    echo "网络接口列表:"
    ifconfig -a | grep -E "^[a-z]" | awk '{print "  " $1}'
    
    echo ""
    echo "活动接口状态:"
    networksetup -listallhardwareports | grep -E "Hardware Port|Device" | while read line; do
        if [[ $line =~ Hardware\ Port ]]; then
            port=$(echo "$line" | cut -d: -f2 | tr -d ' ')
            echo "  端口: $port"
        elif [[ $line =~ Device ]]; then
            device=$(echo "$line" | cut -d: -f2 | tr -d ' ')
            echo "    设备: $device"
            
            # 获取接口状态
            local status=$(ifconfig "$device" 2>/dev/null | grep "status" | awk '{print $2}' || echo "未知")
            echo "    状态: $status"
            
            # 获取IP地址
            local ip=$(ifconfig "$device" 2>/dev/null | grep "inet " | awk '{print $2}' | head -n1 || echo "无")
            echo "    IP地址: $ip"
        fi
    done
    
    echo ""
}

# 检查网络连接
check_connectivity() {
    if [ "${CHECK:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 网络连接检查 ====${NC}"
    
    # 检查默认网关
    echo "默认网关:"
    netstat -rn | grep default | head -n1 | awk '{print "  " $2 " (" $NF ")"}'
    
    echo ""
    echo "连通性测试:"
    
    # 测试本地回环
    echo -n "  本地回环 (127.0.0.1): "
    if ping -c 1 -W 1000 127.0.0.1 >/dev/null 2>&1; then
        echo -e "${GREEN}成功${NC}"
    else
        echo -e "${RED}失败${NC}"
    fi
    
    # 测试网关
    local gateway=$(netstat -rn | grep default | head -n1 | awk '{print $2}')
    if [ -n "$gateway" ]; then
        echo -n "  网关 ($gateway): "
        if ping -c 1 -W 2000 "$gateway" >/dev/null 2>&1; then
            echo -e "${GREEN}成功${NC}"
        else
            echo -e "${RED}失败${NC}"
        fi
    fi
    
    # 测试DNS
    local dns_servers=$(scutil --dns | grep "nameserver\[0\]" | head -n1 | awk '{print $3}')
    if [ -n "$dns_servers" ]; then
        echo -n "  DNS服务器 ($dns_servers): "
        if ping -c 1 -W 2000 "$dns_servers" >/dev/null 2>&1; then
            echo -e "${GREEN}成功${NC}"
        else
            echo -e "${RED}失败${NC}"
        fi
    fi
    
    # 测试外网连接
    echo -n "  外网连接 (8.8.8.8): "
    if ping -c 1 -W 3000 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}成功${NC}"
    else
        echo -e "${RED}失败${NC}"
    fi
    
    echo ""
}

# 检查DNS配置
check_dns() {
    if [ "${CHECK:-false}" != true ] && [ "${DNS:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== DNS配置检查 ====${NC}"
    
    # 显示DNS配置
    echo "DNS服务器配置:"
    scutil --dns | grep -A 20 "resolver #1" | grep "nameserver" | awk '{print "  " $2}'
    
    echo ""
    echo "DNS解析测试:"
    
    # 测试域名解析
    local domains=("google.com" "baidu.com" "apple.com")
    for domain in "${domains[@]}"; do
        echo -n "  解析 $domain: "
        if nslookup "$domain" >/dev/null 2>&1; then
            echo -e "${GREEN}成功${NC}"
            if [ "${DNS:-false}" = true ]; then
                local ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | tail -n1 | awk '{print $2}')
                echo "    IP地址: $ip"
            fi
        else
            echo -e "${RED}失败${NC}"
        fi
    done
    
    echo ""
}

# 测试网络速度
test_speed() {
    if [ "${SPEED:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 网络速度测试 ====${NC}"
    
    # 检查是否有speedtest-cli
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo "未安装speedtest-cli，尝试安装..."
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install speedtest-cli
        elif command -v pip >/dev/null 2>&1; then
            pip install speedtest-cli
        else
            echo "无法安装speedtest-cli，使用简单测试..."
            simple_speed_test
            return
        fi
    fi
    
    # 执行速度测试
    echo "执行速度测试..."
    speedtest-cli --simple
    
    echo ""
}

# 简单速度测试
simple_speed_test() {
    echo "使用curl进行简单下载速度测试..."
    
    # 下载测试文件
    local start_time=$(date +%s)
    curl -o /dev/null -s "http://speedtest.wdc01.softlayer.com/downloads/test10.zip" &
    local curl_pid=$!
    
    # 等待5秒
    sleep 5
    
    # 获取下载速度
    kill $curl_pid 2>/dev/null || true
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$duration" -gt 0 ]; then
        echo "简单下载测试完成，耗时: ${duration}秒"
    fi
}

# 修复网络问题
fix_network() {
    if [ "${FIX:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 修复网络问题 ====${NC}"
    
    # 刷新DNS缓存
    echo "刷新DNS缓存..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    
    # 重置网络接口
    echo "重置网络接口..."
    networksetup -setnetworkserviceenabled "Wi-Fi" off
    sleep 2
    networksetup -setnetworkserviceenabled "Wi-Fi" on
    
    # 重置AirPort
    echo "重置AirPort..."
    sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -z
    
    # 重新获取DHCP租约
    echo "重新获取DHCP租约..."
    local interfaces=$(networksetup -listallhardwareports | grep "Device:" | awk '{print $2}')
    for interface in $interfaces; do
        if [ "$interface" != "en0" ]; then
            continue
        fi
        echo "  重置接口: $interface"
        sudo ipconfig set "$interface" DHCP
    done
    
    echo -e "${GREEN}网络修复完成${NC}"
    echo ""
}

# 重置网络设置
reset_network() {
    if [ "${RESET:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 重置网络设置 ====${NC}"
    echo -e "${YELLOW}警告：这将重置所有网络设置，包括Wi-Fi密码${NC}"
    read -p "确定要继续吗？(y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "取消重置"
        return
    fi
    
    # 删除网络配置文件
    echo "删除网络配置文件..."
    sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist
    sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.network.identification.plist
    sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist
    sudo rm -f /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist
    sudo rm -f /Library/Preferences/SystemConfiguration/preferences.plist
    
    # 重启网络服务
    echo "重启网络服务..."
    sudo kextunload -b com.apple.driver.AppleIntel8254XEthernet 2>/dev/null || true
    sudo kextload -b com.apple.driver.AppleIntel8254XEthernet 2>/dev/null || true
    
    echo -e "${GREEN}网络设置重置完成，请重启系统${NC}"
    echo ""
}

# 显示网络统计信息
show_network_stats() {
    if [ "${CHECK:-false}" != true ]; then
        return
    fi
    
    echo -e "${BLUE}==== 网络统计信息 ====${NC}"
    
    # 网络接口统计
    echo "网络接口统计:"
    netstat -i | head -n 10
    
    echo ""
    echo "活动网络连接:"
    netstat -an | grep ESTABLISHED | head -n 10
    
    echo ""
    echo "监听端口:"
    netstat -an | grep LISTEN | head -n 10
    
    echo ""
}

# 主函数
main() {
    parse_args "$@"
    
    check_interfaces
    check_connectivity
    check_dns
    show_network_stats
    test_speed
    fix_network
    reset_network
}

# 执行主函数
main "$@"

echo "======================================"
echo -e "${GREEN}网络诊断完成！${NC}"
echo "结束时间: $(date)"
echo "日志文件: $LOG_FILE"
