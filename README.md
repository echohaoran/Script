# 📁 My Script Collection

这是一些实用脚本合集，涵盖多平台系统管理、自动化与日常运维任务。所有脚本均经过测试，可直接使用或作为模板二次开发。

## 📂 目录索引

### 🪟 Windows
> 首次执行在powershell执行一次
> `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

#### 系统信息
- [`system-info.ps1`](Windows/system-info.ps1)  
  收集Windows系统硬件、软件、网络等信息并生成报告，支持多种输出选项。

#### 进程监控
- [`process-monitor.ps1`](Windows/process-monitor.ps1)
  监控系统进程，检测异常进程和资源使用情况，支持守护进程模式。

#### 注册表管理
- [`registry-manager.ps1`](Windows/registry-manager.ps1)
  管理Windows注册表，包括备份、恢复、清理等操作。

#### 服务管理
- [`service-manager.ps1`](Windows/service-manager.ps1)
  管理系统服务，包括启动、停止、配置、安装、卸载等操作。

#### 磁盘管理
- [`disk-manager.ps1`](Windows/disk-manager.ps1)
  分析、清理和管理磁盘空间，支持碎片整理和磁盘检查。

#### 导出配置信息
- [`export-system-report.ps1`](Windows/export-system-report.ps1)  
  一键生成包含系统、硬件、CPU、磁盘、网络信息的综合报告，保存为桌面文本文件。

#### 收集系统日志
- [`export-crash-logs.ps1`](Windows/export-crash-logs.ps1)
  收集系统所有日志，以压缩包的形式存放在桌面

#### 清理临时文件
- [`clean-temp-files.ps1`](Windows/clean-temp-files.ps1)
  一键清理临时文件。

#### 导出已安装应用列表
- [`list-installed-software.ps1`](Windows/list-installed-software.ps1)
  导出所有已安装程序（来自"程序和功能"列表）。

#### 试网络连通性
- [`network-diag.ps1`](Windows/network-diag.ps1)
  一键测试网络基础连通性（网关、DNS、公网）。

#### 备份指定文件夹到桌面
- [`backup-folder.ps1`](Windows/backup-folder.ps1)
  备份指定文件夹到桌面，自动压缩为 ZIP。

### 🐧 Linux

#### 系统信息
- [`system-info.sh`](Linux/system-info.sh)  
  收集Linux系统硬件、软件、网络等信息并生成报告。

#### 备份工具
- [`backup.sh`](Linux/backup.sh)
  备份指定目录，支持完整备份和增量备份。

#### 系统清理
- [`cleanup.sh`](Linux/cleanup.sh)
  清理系统临时文件、日志、缓存等释放磁盘空间。

#### 网络诊断
- [`network-diag.sh`](Linux/network-diag.sh)
  诊断网络连接问题，包括连通性、DNS、速度测试等。

#### 进程监控
- [`process-monitor.sh`](Linux/process-monitor.sh)
  监控系统进程，检测异常进程和资源使用情况。

#### 原有脚本
- [`system-monitor.sh`](Linux/system-monitor.sh)  
  每隔10秒记录 CPU、内存、磁盘使用率到 `/tmp/log/`，自动删除超过10分钟的旧日志。

### 🍏 macOS

#### 系统信息
- [`system-info.sh`](MacOS/system-info.sh)  
  收集macOS系统硬件、软件、网络等信息并生成报告。

#### 应用管理
- [`app-manager.sh`](MacOS/app-manager.sh)
  管理macOS应用程序的安装、更新、卸载。

#### 系统优化
- [`system-optimizer.sh`](MacOS/system-optimizer.sh)
  优化macOS系统性能和设置，包括Dock、Finder、安全设置等。

#### 磁盘管理
- [`disk-manager.sh`](MacOS/disk-manager.sh)
  分析、清理和管理磁盘空间，查找重复文件和大文件。

#### 网络诊断
- [`network-diag.sh`](MacOS/network-diag.sh)
  诊断和修复macOS网络连接问题。

#### 快速配置 macOS 开发环境
- [`setup-defaults.sh`](Macos/setup-defaults.sh)  
  快速配置 macOS 常用系统偏好（如显示扩展名、Dock 行为、Finder 选项等）。

### 🐍 Python

#### 系统信息
- [`system-info.py`](Python/system-info.py)  
  收集系统硬件、软件、网络等信息并生成报告，支持多平台。

#### 文件同步
- [`file-sync.py`](Python/file-sync.py)
  在两个目录之间同步文件，支持多种同步模式。

#### 批量重命名
- [`batch-rename.py`](Python/batch-rename.py)
  批量重命名文件，支持多种重命名模式。

#### 图像处理
- [`image-processor.py`](Python/image-processor.py)
  批量处理图像文件，支持缩放、转换、水印等操作。

#### 网络监控
- [`network-monitor.py`](Python/network-monitor.py)
  监控网络连接、速度、流量等，支持告警功能。

#### 文件备份指定目录
- [`backup-tool.py`](Python/backup-tool.py)  
  递归备份指定目录，生成带时间戳的副本。

### 🧰 工具脚本

#### 密码生成器
- [`password-generator.sh`](Utils/password-generator.sh)
  生成安全的随机密码，支持多种字符类型和强度选项。

#### 哈希校验
- [`hash-checker.sh`](Utils/hash-checker.sh)
  计算和验证文件哈希值，支持多种哈希算法。

#### 文件分割
- [`file-splitter.sh`](Utils/file-splitter.sh)
  将大文件分割成小块，或将多个文件合并。

#### 编码转换
- [`encoding-converter.sh`](Utils/encoding-converter.sh)
  批量转换文件编码格式，支持自动检测编码。

#### 定时任务
- [`cron-manager.sh`](Utils/cron-manager.sh)
  管理系统定时任务（cron），支持添加、删除、备份等操作。

#### Shell脚本模板
- [`template.sh`](Utils/template.sh)  
  健壮的 Shell 脚本模板，包含严格模式、日志记录和基础错误处理。

---

## 💡 使用建议

### Windows
- 确保PowerShell执行策略允许运行脚本：
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
- 某些管理操作需要管理员权限，请以管理员身份运行PowerShell。

### Linux
- 赋予脚本执行权限：`chmod +x script.sh`
- 或者使用：`sh/bash + script.sh`
- 某些操作可能需要sudo权限。

### macOS
- 赋予脚本执行权限：`chmod +x script.sh`
- 某些系统设置修改需要sudo权限。

### Python
- 确保已安装Python 3.x：`python3 --version`
- 可能需要安装依赖库：`pip3 install -r requirements.txt`

### 通用
- 所有脚本均使用 UTF-8 编码，支持中文环境。
- 建议在测试环境中先运行，确认无误后再在生产环境使用。
- 欢迎提交 Issue 或 PR 改进建议！
