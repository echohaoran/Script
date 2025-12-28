#!/bin/bash
# Shell 脚本通用模板
set -euo pipefail  # 严格模式

LOG_FILE="/tmp/script.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] 脚本开始执行"

# 示例任务
echo "当前用户: $USER"
echo "工作目录: $(pwd)"

# 错误处理示例
if ! command -v ls >/dev/null 2>&1; then
    echo "错误: ls 命令不可用"
    exit 1
fi

echo "[$(date)] 脚本执行完毕"