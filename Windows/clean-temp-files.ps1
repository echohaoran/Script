# 文件名：clean-temp-files.ps1
# 功能：清理当前用户的临时文件、Windows临时目录、回收站（可选）
# 注意：建议在空闲时运行，避免误删正在使用的文件

Write-Host "正在清理临时文件..." -ForegroundColor Yellow

# 1. 清理当前用户临时目录 (%TEMP%)
$UserTemp = $env:TEMP
if (Test-Path $UserTemp) {
    Get-ChildItem $UserTemp -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ 已清理用户临时目录：$UserTemp"
}

# 2. 清理系统临时目录 (C:\Windows\Temp)
$SystemTemp = "$env:SystemRoot\Temp"
if (Test-Path $SystemTemp) {
    Get-ChildItem $SystemTemp -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✓ 已清理系统临时目录：$SystemTemp"
}

# 3. 清空回收站（当前用户）
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "✓ 已清空回收站"
} catch {
    Write-Host "⚠ 无法清空回收站（可能需要管理员权限）"
}

Write-Host "清理完成。" -ForegroundColor Green