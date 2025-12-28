#!/bin/bash

# macOS系统信息收集脚本
# 功能：收集macOS系统硬件、软件、网络等信息并生成报告
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
echo "      macOS系统信息收集工具"
echo "======================================"
echo "开始时间: $(date)"
echo "报告文件: $REPORT_FILE"
echo ""

# 系统基本信息
echo "==== 系统基本信息 ====" >> "$REPORT_FILE"
echo "主机名: $(hostname)" >> "$REPORT_FILE"
echo "操作系统: $(sw_vers -productName) $(sw_vers -productVersion)" >> "$REPORT_FILE"
echo "系统版本: $(sw_vers -buildVersion)" >> "$REPORT_FILE"
echo "内核版本: $(uname -r)" >> "$REPORT_FILE"
echo "系统架构: $(uname -m)" >> "$REPORT_FILE"
echo "序列号: $(system_profiler SPHardwareDataType | grep "Serial Number" | awk -F": " '{print $2}')" >> "$REPORT_FILE"
echo "UUID: $(system_profiler SPHardwareDataType | grep "Hardware UUID" | awk -F": " '{print $2}')" >> "$REPORT_FILE"
echo "当前用户: $(whoami)" >> "$REPORT_FILE"
echo "启动时间: $(system_profiler SPSoftwareDataType | grep "System Startup Time" | awk -F": " '{print $2}')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 硬件信息
echo "==== 硬件信息 ====" >> "$REPORT_FILE"
system_profiler SPHardwareDataType >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# CPU信息
echo "==== CPU 信息 ====" >> "$REPORT_FILE"
sysctl -n machdep.cpu.brand_string >> "$REPORT_FILE"
echo "CPU核心数: $(sysctl -n hw.ncpu)" >> "$REPORT_FILE"
echo "CPU频率: $(sysctl -n hw.cpufrequency | awk '{printf "%.2f GHz", $1/1000000000}')" >> "$REPORT_FILE"
echo "L2缓存: $(sysctl -n hw.l2cachesize | awk '{printf "%.1f MB", $1/1048576}')" >> "$REPORT_FILE"
echo "L3缓存: $(sysctl -n hw.l3cachesize | awk '{printf "%.1f MB", $1/1048576}')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 内存信息
echo "==== 内存信息 ====" >> "$REPORT_FILE"
echo "总内存: $(sysctl -n hw.memsize | awk '{printf "%.1f GB", $1/1073741824}')" >> "$REPORT_FILE"
vm_stat | perl -ne '/page size of (\d+)/ and $ps=$1; /Pages\s+(.+):\s+(\d+)/ and printf("%-16s % 16.2f Mi\n", $1, $2*$ps/1048576);' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 存储信息
echo "==== 存储信息 ====" >> "$REPORT_FILE"
df -h >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
diskutil list >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 网络信息
echo "==== 网络信息 ====" >> "$REPORT_FILE"
ifconfig >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
netstat -rn >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
scutil --nwi >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 已安装应用
echo "==== 已安装应用 ====" >> "$REPORT_FILE"
echo "从LaunchPad安装的应用:" >> "$REPORT_FILE"
ls /Applications >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"
echo "Homebrew安装的应用:" >> "$REPORT_FILE"
brew list 2>/dev/null || echo "未安装Homebrew" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 系统偏好设置
echo "==== 系统偏好设置 ====" >> "$REPORT_FILE"
defaults read com.apple.LaunchServices >> "$REPORT_FILE" 2>/dev/null || echo "无法读取LaunchServices设置" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 网络连接
echo "==== 网络连接 ====" >> "$REPORT_FILE"
lsof -i -P -n | grep ESTABLISHED >> "$REPORT_FILE" 2>/dev/null || echo "无活跃网络连接" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 系统进程
echo "==== 系统进程（前20个） ====" >> "$REPORT_FILE"
ps aux | sort -rk 3,3 | head -n 21 >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 开放端口
echo "==== 开放端口 ====" >> "$REPORT_FILE"
netstat -an | grep LISTEN >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 系统日志摘要
echo "==== 系统日志摘要（最近10条错误） ====" >> "$REPORT_FILE"
log show --predicate 'category == "error"' --last 1h --style compact >> "$REPORT_FILE" 2>/dev/null || echo "无法读取系统日志" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 启动项
echo "==== 启动项 ====" >> "$REPORT_FILE"
echo "登录项:" >> "$REPORT_FILE"
osascript -e 'tell application "System Events" to get the name of every login item' >> "$REPORT_FILE" 2>/dev/null || echo "无法获取登录项" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "LaunchAgents:" >> "$REPORT_FILE"
ls ~/Library/LaunchAgents >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"
echo "LaunchDaemons:" >> "$REPORT_FILE"
ls /Library/LaunchDaemons >> "$REPORT_FILE" 2>/dev/null
echo "" >> "$REPORT_FILE"

# 安全信息
echo "==== 安全信息 ====" >> "$REPORT_FILE"
echo "Gatekeeper状态:" >> "$REPORT_FILE"
spctl --status >> "$REPORT_FILE" 2>/dev/null || echo "无法获取Gatekeeper状态" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "SIP状态:" >> "$REPORT_FILE"
csrutil status >> "$REPORT_FILE" 2>/dev/null || echo "无法获取SIP状态" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "FileVault状态:" >> "$REPORT_FILE"
fdesetup status >> "$REPORT_FILE" 2>/dev/null || echo "无法获取FileVault状态" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# 完成时间
echo "完成时间: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "macOS系统信息收集完成！"
echo "报告已保存到: $REPORT_FILE"
echo "日志已保存到: $LOG_FILE"