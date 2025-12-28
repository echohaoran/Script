#!/bin/bash

# 系统信息收集脚本
# 功能：收集系统硬件、软件、网络等信息并生成报告
# 使用方法：./system-info.sh

set -euo pipefail

# 日志文件路径
LOG_FILE="/tmp/system-info-$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="$HOME/system-report-$(date +%Y%m%d_%H%M%S).txt"

# 创建日志文件
touch "$LOG_FILE"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "======================================"
echo "        系统信息收集工具"
echo "======================================"
echo "开始时间: $(date)"
echo "报告文件: $REPORT_FILE"
echo ""

# 系统基本信息
echo "==== 系统基本信息 ====" >> "$REPORT_FILE"
echo "主机名: $(hostname)" >> "$REPORT_FILE"
echo "操作系统: $(uname -a)" >> "$REPORT_FILE"
echo "内核版本: $(uname -r)" >> "$REPORT_FILE"
echo "系统架构: $(uname -m)" >> "$REPORT_FILE"
echo "运行时间: $(uptime -p 2>/dev/null || uptime)" >> "$REPORT_FILE"
echo "当前用户: $(whoami)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# CPU信息
echo "==== CPU 信息 ====" >> "$REPORT_FILE"
if command -v lscpu >/dev/null 2>&1; then
    lscpu >> "$REPORT_FILE"
else
    cat /proc/cpuinfo | grep "model name" | head -1 >> "$REPORT_FILE"
    echo "CPU核心数: $(nproc)" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 内存信息
echo "==== 内存信息 ====" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 磁盘信息
echo "==== 磁盘信息 ====" >> "$REPORT_FILE"
df -h >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 网络信息
echo "==== 网络信息 ====" >> "$REPORT_FILE"
ip addr show >> "$REPORT_FILE" 2>/dev/null || ifconfig >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

# 路由表
echo "==== 路由表 ====" >> "$REPORT_FILE"
ip route show >> "$REPORT_FILE" 2>/dev/null || route -n >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

# 已安装软件包（根据不同的包管理器）
echo "==== 已安装软件包 ====" >> "$REPORT_FILE"
if command -v dpkg >/dev/null 2>&1; then
    echo "Debian/Ubuntu 系统 - 已安装包数量: $(dpkg -l | grep '^ii' | wc -l)" >> "$REPORT_FILE"
elif command -v rpm >/dev/null 2>&1; then
    echo "RedHat/CentOS 系统 - 已安装包数量: $(rpm -qa | wc -l)" >> "$REPORT_FILE"
elif command -v pacman >/dev/null 2>&1; then
    echo "Arch Linux 系统 - 已安装包数量: $(pacman -Q | wc -l)" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 系统服务状态
echo "==== 系统服务状态 ====" >> "$REPORT_FILE"
if command -v systemctl >/dev/null 2>&1; then
    echo "运行中的服务数量: $(systemctl list-units --type=service --state=running | wc -l)" >> "$REPORT_FILE"
    echo "失败的服务:" >> "$REPORT_FILE"
    systemctl --failed --no-pager >> "$REPORT_FILE" 2>/dev/null || echo "无失败服务" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 最近登录记录
echo "==== 最近登录记录 ====" >> "$REPORT_FILE"
last -n 10 >> "$REPORT_FILE" 2>/dev/null || echo "无法获取登录记录" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 系统进程
echo "==== 系统进程（前20个） ====" >> "$REPORT_FILE"
ps aux --sort=-%cpu | head -n 21 >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 开放端口
echo "==== 开放端口 ====" >> "$REPORT_FILE"
if command -v ss >/dev/null 2>&1; then
    ss -tuln >> "$REPORT_FILE"
elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 系统日志摘要
echo "==== 系统日志摘要（最近10条错误） ====" >> "$REPORT_FILE"
if [ -f /var/log/syslog ]; then
    grep -i error /var/log/syslog | tail -n 10 >> "$REPORT_FILE" 2>/dev/null || echo "无错误日志" >> "$REPORT_FILE"
elif [ -f /var/log/messages ]; then
    grep -i error /var/log/messages | tail -n 10 >> "$REPORT_FILE" 2>/dev/null || echo "无错误日志" >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 完成时间
echo "完成时间: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "系统信息收集完成！"
echo "报告已保存到: $REPORT_FILE"
echo "日志已保存到: $LOG_FILE"