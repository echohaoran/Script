# 文件名：backup-folder.ps1
# 功能：备份指定文件夹到桌面，自动压缩为 ZIP
# 使用示例：修改 $SourcePath 为目标路径

$SourcePath = "C:\ImportantData"  # ← 请修改为你想备份的目录
if (-not (Test-Path $SourcePath)) {
    Write-Host "❌ 源目录不存在：$SourcePath" -ForegroundColor Red
    exit 1
}

$DateStr = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupName = (Split-Path $SourcePath -Leaf) + "_Backup_$DateStr"
$ZipPath = "$env:USERPROFILE\Desktop\$BackupName.zip"

Write-Host "正在备份 $SourcePath → $ZipPath ..."

# 使用 Compress-Archive 压缩（PowerShell 5.0+ 内置）
Compress-Archive -Path "$SourcePath\*" -DestinationPath $ZipPath -Force

if (Test-Path $ZipPath) {
    Write-Host "✅ 备份完成：$ZipPath" -ForegroundColor Green
} else {
    Write-Host "❌ 备份失败" -ForegroundColor Red
}