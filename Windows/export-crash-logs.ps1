# 设置当前用户的 PowerShell 执行策略为 RemoteSigned
# 目的：允许运行本地编写的脚本（如本脚本），但阻止未经签名的远程脚本
# -Scope CurrentUser 表示仅对当前用户生效，无需管理员权限，也更安全
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 文件名：export-crash-logs.ps1
# 功能：一键收集 Windows 故障相关日志（系统、应用、安全事件等），生成可交付的压缩包
# 输出：桌面生成 Troubleshoot_时间戳.zip，包含 .evtx 日志文件和可读文本摘要

# 生成当前时间戳字符串，格式为 YYYYMMDD_HHMMSS（例如：20251228_143022）
# 用于确保每次生成的日志目录和文件名唯一
$DateStr = Get-Date -Format "yyyyMMdd_HHmmss"

# 定义临时日志目录路径（位于系统临时目录下）
# 例如：C:\Users\用户名\AppData\Local\Temp\Troubleshoot_20251228_143022
$LogDir = "$env:TEMP\Troubleshoot_$DateStr"

# 定义最终输出的 ZIP 压缩包路径，保存到当前用户的桌面
$ZipPath = "$env:USERPROFILE\Desktop\Troubleshoot_$DateStr.zip"

# 创建临时日志目录（-Force 表示如果已存在则不报错，且自动创建父目录）
# Out-Null 用于屏蔽命令的输出（避免控制台打印创建成功的消息）
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# ------------------------------------------------------------
# 1. 使用 wevtutil 工具导出 Windows 事件日志（.evtx 格式）
# .evtx 文件可用 Windows 自带的“事件查看器”（eventvwr.msc）打开分析
# ------------------------------------------------------------

# 导出 System 日志中“错误（Level=2）、关键（Level=1）、警告（Level=3）”的事件
# /q 参数指定 XPath 查询过滤器，只导出关键问题事件，减小文件体积
wevtutil epl System "$LogDir\System.evtx" /q:"*[System[(Level=1 or Level=2 or Level=3)]]"

# 同样导出 Application 日志中的错误/警告事件
wevtutil epl Application "$LogDir\Application.evtx" /q:"*[System[(Level=1 or Level=2 or Level=3)]]"

# 同时导出完整的 System 和 Application 日志（无过滤），便于深度排查
wevtutil epl System "$LogDir\System_full.evtx"
wevtutil epl Application "$LogDir\Application_full.evtx"

# ------------------------------------------------------------
# 尝试导出 Security（安全）日志（仅当以管理员身份运行时才可能成功）
# Security 日志通常受保护，普通用户无读取权限
# ------------------------------------------------------------

# 检查当前 PowerShell 是否以管理员身份运行
# 通过 .NET 的 WindowsPrincipal 类判断当前用户是否属于内置管理员角色
if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # 如果是管理员，尝试导出 Security 日志
    # 2>$null 表示将错误输出（stderr）丢弃，避免因权限不足或日志被占用而报错
    wevtutil epl Security "$LogDir\Security_full.evtx" 2>$null
}

# ------------------------------------------------------------
# 2. 生成人类可读的文本摘要（Summary.txt），便于快速浏览关键信息
# ------------------------------------------------------------

# 定义摘要文件路径
$SummaryFile = "$LogDir\Summary.txt"

# 初始化一个字符串数组，用于逐段构建摘要内容
$Summary = @()

# 添加系统基本信息部分（调用 systeminfo 命令）
$Summary += "=== 系统摘要 ==="
# systeminfo 输出多行文本，必须通过 Out-String 转为单个字符串才能正确加入数组
$Summary += systeminfo | Out-String

# 添加近期系统错误与警告部分（最近7天）
$Summary += "`n=== 近期错误与警告（最近7天）==="
# 计算7天前的时间点，作为日志查询的起始时间
$StartTime = (Get-Date).AddDays(-7)
# 使用 Get-WinEvent 按哈希表过滤日志：
#   - LogName='System'：系统日志
#   - Level=1,2,3：关键、错误、警告
#   - StartTime：时间范围
#   - MaxEvents 100：最多取100条，避免日志过大
#   - ErrorAction SilentlyContinue：若无匹配事件也不报错
# Format-List 指定输出字段，Out-String 确保格式化结果能正确加入文本
$Summary += Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2,3; StartTime=$StartTime} -MaxEvents 100 -ErrorAction SilentlyContinue | Format-List TimeCreated, Id, LevelDisplayName, ProviderName, Message | Out-String

# 添加应用程序错误部分（最近7天）
$Summary += "`n=== 应用程序错误（最近7天）==="
$Summary += Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2,3; StartTime=$StartTime} -MaxEvents 100 -ErrorAction SilentlyContinue | Format-List TimeCreated, Id, LevelDisplayName, ProviderName, Message | Out-String

# 将摘要内容写入 Summary.txt，使用 UTF8 编码确保中文显示正常
$Summary | Out-File -FilePath $SummaryFile -Encoding UTF8

# ------------------------------------------------------------
# 3. 将所有日志文件打包成 ZIP 压缩包，便于交付或上传
# ------------------------------------------------------------

# 使用 PowerShell 内置的 Compress-Archive 命令
# -Path "$LogDir\*" 表示压缩该目录下所有文件
# -Force 表示如果 ZIP 文件已存在则覆盖
Compress-Archive -Path "$LogDir\*" -DestinationPath $ZipPath -Force

# 输出成功提示信息（绿色显示，提升用户体验）
Write-Host "✅ 故障日志已导出至：$ZipPath" -ForegroundColor Green
# 列出压缩包中包含的关键内容说明
Write-Host "📄 包含：System/Application.evtx（完整+过滤版）、Summary.txt"