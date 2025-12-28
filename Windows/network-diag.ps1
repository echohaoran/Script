# 文件名：network-diag.ps1
# 功能：一键测试网络基础连通性（网关、DNS、公网）
# 适合用于用户报“上不了网”时快速判断问题层级

Write-Host "=== 网络诊断开始 ===" -ForegroundColor Cyan

# 获取默认网关和 DNS
$NetConfig = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
if (-not $NetConfig) { Write-Host "⚠ 未检测到活动网络适配器"; exit }

$Gateway = $NetConfig.IPv4DefaultGateway.NextHop
$DnsServers = $NetConfig.DNSServer.ServerAddresses

Write-Host "活动适配器: $($NetConfig.InterfaceAlias)"
Write-Host "IP 地址: $($NetConfig.IPv4Address.IPAddress)"
Write-Host "默认网关: $Gateway"

# 1. 测试网关连通性（判断局域网是否通）
if (Test-Connection $Gateway -Count 2 -Quiet) {
    Write-Host "✓ 网关 $Gateway 连通"
} else {
    Write-Host "✗ 无法连通网关！可能是本地网络或网线/WiFi 问题" -ForegroundColor Red
}

# 2. 测试 DNS 服务器响应
foreach ($dns in $DnsServers) {
    if (Test-Connection $dns -Count 1 -Quiet) {
        Write-Host "✓ DNS 服务器 $dns 响应正常"
    } else {
        Write-Host "✗ DNS 服务器 $dns 无响应" -ForegroundColor Red
    }
}

# 3. 测试公网解析与访问（使用知名域名）
$TestDomain = "www.baidu.com"
$Resolved = Resolve-DnsName $TestDomain -ErrorAction SilentlyContinue
if ($Resolved) {
    Write-Host "✓ DNS 解析 $TestDomain 成功：$($Resolved.IPAddress)"
    if (Test-Connection $Resolved.IPAddress[0] -Count 2 -Quiet) {
        Write-Host "✓ 公网访问正常"
    } else {
        Write-Host "✗ 可解析但无法访问公网（可能防火墙/代理问题）" -ForegroundColor Red
    }
} else {
    Write-Host "✗ DNS 无法解析 $TestDomain（DNS 或网络配置问题）" -ForegroundColor Red
}

Write-Host "=== 网络诊断结束 ===" -ForegroundColor Cyan