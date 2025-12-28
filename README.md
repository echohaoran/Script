# 📁 My Script Collection

这是一些实用脚本合集，涵盖多平台系统管理、自动化与日常运维任务。所有脚本均经过测试，可直接使用或作为模板二次开发。

## 📂 目录索引

### 🪟 Windows
- [`export-system-report.ps1`](windows/export-system-report.ps1)  
  一键生成包含系统、硬件、CPU、磁盘、网络信息的综合报告，保存为桌面文本文件。

### 🐧 Linux
- [`system-monitor.sh`](linux/system-monitor.sh)  
  每隔10秒记录 CPU、内存、磁盘使用率到 `/tmp/log/`，自动删除超过10分钟的旧日志。

### 🍏 macOS
- [`setup-defaults.sh`](macos/setup-defaults.sh)  
  快速配置 macOS 常用系统偏好（如显示扩展名、Dock 行为、Finder 选项等）。

### 🐍 Python
- [`backup-tool.py`](python/backup-tool.py)  
  递归备份指定目录，生成带时间戳的副本。用法：`python3 backup-tool.py /source /dest`

### 🧰 工具模板
- [`template.sh`](utils/template.sh)  
  健壮的 Shell 脚本模板，包含严格模式、日志记录和基础错误处理，适合快速开发。

---

> 💡 **使用建议**  
> - 所有脚本均使用 UTF-8 编码，支持中文环境,直接复制粘贴即可。
> - Linux/macOS 脚本需赋予执行权限：`chmod +x script.sh`  
    - 或者使用: `sh/bash + script.sh`
> - 欢迎提交 Issue 或 PR 改进建议！
