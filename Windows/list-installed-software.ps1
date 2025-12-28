# 文件名：list-installed-software.ps1
# 功能：导出所有已安装程序（来自“程序和功能”列表）
# 输出：桌面生成 InstalledSoftware_时间戳.csv

$DateStr = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputPath = "$env:USERPROFILE\Desktop\InstalledSoftware_$DateStr.csv"

# 从注册表读取32位和64位已安装软件
$UninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$SoftwareList = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and !$_.SystemComponent } |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName

# 导出为 CSV（支持 Excel 打开）
$SoftwareList | Export-Csv -Path $OutputPath -Encoding UTF8 -NoTypeInformation

Write-Host "已安装软件列表已保存至：$OutputPath" -ForegroundColor Green