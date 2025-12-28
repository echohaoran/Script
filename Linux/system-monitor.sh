#!/bin/bash
# 每隔10秒记录系统资源占用，保留最近10分钟日志（6个文件）
LOG_DIR="/tmp/log"
mkdir -p "$LOG_DIR"

# 获取当前时间戳（秒级）
NOW=$(date +%s)
LOG_FILE="$LOG_DIR/system_$(date +%Y%m%d_%H%M%S).log"

# 记录 CPU、内存、磁盘使用率
{
    echo "=== $(date) ==="
    echo "CPU (idle%): $(top -bn1 | awk '/Cpu/ {print $8}' | cut -d'.' -f1)"
    echo "Memory (free/total MB): $(free -m | awk 'NR==2{printf "%s/%s", $4,$2}')"
    echo "Disk / usage: $(df -h / | awk 'NR==2 {print $5}')"
    echo ""
} > "$LOG_FILE"

# 删除10分钟前的日志（600秒）
find "$LOG_DIR" -name "system_*.log" -type f -mmin +10 -delete