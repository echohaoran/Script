
$ReportPath = "$env:USERPROFILE\Desktop\SystemReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$Report = @()

$Report += "=== 系统信息 ==="
$Report += systeminfo
$Report += ""

$Report += "=== 硬件摘要 ==="
$Report += Get-WmiObject -Class Win32_ComputerSystem | Format-List Manufacturer, Model, TotalPhysicalMemory
$Report += ""

$Report += "=== CPU 信息 ==="
$Report += Get-WmiObject -Class Win32_Processor | Format-List Name, NumberOfCores, MaxClockSpeed
$Report += ""

$Report += "=== 磁盘信息 ==="
$Report += Get-WmiObject -Class Win32_DiskDrive | Format-List Model, Size, InterfaceType
$Report += ""

$Report += "=== 网络适配器 ==="
$Report += Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, LinkSpeed -AutoSize

$Report | Out-File -FilePath $ReportPath -Encoding UTF8
Write-Host "报告已保存至: $ReportPath"