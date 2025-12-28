# Windows服务管理脚本
# 功能：管理系统服务，包括启动、停止、配置等操作
# 使用方法：.\service-manager.ps1 [命令] [服务名] [选项]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("list", "start", "stop", "restart", "status", "config", "install", "uninstall", "backup", "restore")]
    [string]$Command,
    
    [string]$ServiceName,
    [string]$DisplayName,
    [string]$Description,
    [string]$BinaryPathName,
    [string]$StartType = "Automatic",
    [string]$BackupPath = "$env:USERPROFILE\Desktop\Service-Backups",
    [string]$RestoreFile,
    [switch]$Force,
    [switch]$Verbose,
    [switch]$All,
    [switch]$Running,
    [switch]$Stopped
)

# 颜色输出
function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    
    Write-Host $Message -ForegroundColor $Color
}

# 创建日志
$LogFile = Join-Path $env:TEMP "service-manager-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    if ($Verbose) {
        Write-Host $LogEntry
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ServiceInfo {
    param([string]$Name)
    
    try {
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($service) {
            $serviceConfig = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
            
            $serviceInfo = @{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                StartType = $service.StartType
                BinaryPathName = $serviceConfig.PathName
                Description = $serviceConfig.Description
                StartName = $serviceConfig.StartName
                ServiceType = $serviceConfig.ServiceType
                ProcessId = $serviceConfig.ProcessId
                CanPauseAndContinue = $service.CanPauseAndContinue
                CanShutdown = $service.CanShutdown
                CanStop = $service.CanStop
            }
            
            return $serviceInfo
        }
    } catch {
        Write-Log "获取服务信息失败: $($_.Exception.Message)"
    }
    
    return $null
}

function List-Services {
    Write-Log "列出服务..."
    
    $services = @()
    
    if ($All) {
        $services = Get-Service
    } elseif ($Running) {
        $services = Get-Service | Where-Object { $_.Status -eq "Running" }
    } elseif ($Stopped) {
        $services = Get-Service | Where-Object { $_.Status -eq "Stopped" }
    } elseif ($ServiceName) {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            $services = @($service)
        }
    } else {
        $services = Get-Service | Where-Object { $_.StartType -eq "Automatic" -or $_.StartType -eq "AutomaticDelayedStart" }
    }
    
    if ($services.Count -gt 0) {
        Write-ColorOutput "找到 $($services.Count) 个服务:" -Color Green
        Write-ColorOutput "$("Name".PadRight(30)) $("DisplayName".PadRight(50)) $("Status".PadRight(10)) StartType" -Color Cyan
        Write-ColorOutput $("-" * 100) -Color Gray
        
        foreach ($service in $services) {
            $name = $service.Name.PadRight(30)
            $displayName = $service.DisplayName.PadRight(50)
            $status = $service.Status.PadRight(10)
            $startType = $service.StartType
            
            Write-ColorOutput "$name$displayName$status$startType" -Color White
        }
    } else {
        Write-ColorOutput "未找到匹配的服务" -Color Yellow
    }
    
    return $services
}

function Start-ServiceEx {
    param([string]$Name)
    
    Write-Log "启动服务: $Name"
    
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColorOutput "服务不存在: $Name" -Color Red
        return $false
    }
    
    if ($service.Status -eq "Running") {
        Write-ColorOutput "服务已在运行: $Name" -Color Yellow
        return $true
    }
    
    try {
        Start-Service -Name $Name -ErrorAction Stop
        
        # 等待服务启动
        $timeout = 30
        $elapsed = 0
        
        while ($elapsed -lt $timeout) {
            $service = Get-Service -Name $Name
            if ($service.Status -eq "Running") {
                Write-ColorOutput "服务启动成功: $Name" -Color Green
                return $true
            }
            
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        Write-ColorOutput "服务启动超时: $Name" -Color Red
        return $false
        
    } catch {
        Write-ColorOutput "服务启动失败: $Name - $($_.Exception.Message)" -Color Red
        Write-Log "服务启动失败: $Name - $($_.Exception.Message)"
        return $false
    }
}

function Stop-ServiceEx {
    param([string]$Name)
    
    Write-Log "停止服务: $Name"
    
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColorOutput "服务不存在: $Name" -Color Red
        return $false
    }
    
    if ($service.Status -eq "Stopped") {
        Write-ColorOutput "服务已停止: $Name" -Color Yellow
        return $true
    }
    
    if (-not $service.CanStop) {
        Write-ColorOutput "服务无法停止: $Name" -Color Red
        return $false
    }
    
    try {
        Stop-Service -Name $Name -Force -ErrorAction Stop
        
        # 等待服务停止
        $timeout = 30
        $elapsed = 0
        
        while ($elapsed -lt $timeout) {
            $service = Get-Service -Name $Name
            if ($service.Status -eq "Stopped") {
                Write-ColorOutput "服务停止成功: $Name" -Color Green
                return $true
            }
            
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        Write-ColorOutput "服务停止超时: $Name" -Color Red
        return $false
        
    } catch {
        Write-ColorOutput "服务停止失败: $Name - $($_.Exception.Message)" -Color Red
        Write-Log "服务停止失败: $Name - $($_.Exception.Message)"
        return $false
    }
}

function Restart-ServiceEx {
    param([string]$Name)
    
    Write-Log "重启服务: $Name"
    
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColorOutput "服务不存在: $Name" -Color Red
        return $false
    }
    
    try {
        Restart-Service -Name $Name -Force -ErrorAction Stop
        
        # 等待服务重启
        $timeout = 60
        $elapsed = 0
        
        while ($elapsed -lt $timeout) {
            $service = Get-Service -Name $Name
            if ($service.Status -eq "Running") {
                Write-ColorOutput "服务重启成功: $Name" -Color Green
                return $true
            }
            
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        Write-ColorOutput "服务重启超时: $Name" -Color Red
        return $false
        
    } catch {
        Write-ColorOutput "服务重启失败: $Name - $($_.Exception.Message)" -Color Red
        Write-Log "服务重启失败: $Name - $($_.Exception.Message)"
        return $false
    }
}

function Get-ServiceStatus {
    param([string]$Name)
    
    Write-Log "获取服务状态: $Name"
    
    $serviceInfo = Get-ServiceInfo -Name $Name
    if (-not $serviceInfo) {
        Write-ColorOutput "服务不存在: $Name" -Color Red
        return
    }
    
    Write-ColorOutput "服务详细信息:" -Color Cyan
    Write-ColorOutput "  名称: $($serviceInfo.Name)" -Color White
    Write-ColorOutput "  显示名称: $($serviceInfo.DisplayName)" -Color White
    Write-ColorOutput "  状态: $($serviceInfo.Status)" -Color White
    Write-ColorOutput "  启动类型: $($serviceInfo.StartType)" -Color White
    Write-ColorOutput "  可执行路径: $($serviceInfo.BinaryPathName)" -Color White
    Write-ColorOutput "  描述: $($serviceInfo.Description)" -Color White
    Write-ColorOutput "  登录身份: $($serviceInfo.StartName)" -Color White
    Write-ColorOutput "  服务类型: $($serviceInfo.ServiceType)" -Color White
    
    if ($serviceInfo.ProcessId) {
        $process = Get-Process -Id $serviceInfo.ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            Write-ColorOutput "  进程ID: $($serviceInfo.ProcessId)" -Color White
            Write-ColorOutput "  进程名称: $($process.ProcessName)" -Color White
            Write-ColorOutput "  CPU时间: $($process.CPU)" -Color White
            Write-ColorOutput "  内存使用: $([math]::Round($process.WorkingSet64 / 1MB, 2)) MB" -Color White
        }
    }
    
    Write-ColorOutput "  可暂停: $($serviceInfo.CanPauseAndContinue)" -Color White
    Write-ColorOutput "  可关闭: $($serviceInfo.CanShutdown)" -Color White
    Write-ColorOutput "  可停止: $($serviceInfo.CanStop)" -Color White
    
    return $serviceInfo
}

function Set-ServiceConfig {
    param(
        [string]$Name,
        [string]$StartType,
        [string]$DisplayName,
        [string]$Description
    )
    
    Write-Log "配置服务: $Name"
    
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColorOutput "服务不存在: $Name" -Color Red
        return $false
    }
    
    try {
        # 设置启动类型
        if ($StartType) {
            Set-Service -Name $Name -StartupType $StartType
            Write-ColorOutput "启动类型设置为: $StartType" -Color Green
        }
        
        # 设置显示名称
        if ($DisplayName) {
            $serviceConfig = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
            $serviceConfig.DisplayName = $DisplayName
            $serviceConfig | Set-CimInstance
            Write-ColorOutput "显示名称设置为: $DisplayName" -Color Green
        }
        
        # 设置描述
        if ($Description) {
            $serviceConfig = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
            $serviceConfig.Description = $Description
            $serviceConfig | Set-CimInstance
            Write-ColorOutput "描述设置为: $Description" -Color Green
        }
        
        Write-ColorOutput "服务配置完成: $Name" -Color Green
        return $true
        
    } catch {
        Write-ColorOutput "服务配置失败: $Name - $($_.Exception.Message)" -Color Red
        Write-Log "服务配置失败: $Name - $($_.Exception.Message)"
        return $false
    }
}

function Install-ServiceEx {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Description,
        [string]$BinaryPathName,
        [string]$StartType
    )
    
    Write-Log "安装服务: $Name"
    
    if (-not $BinaryPathName) {
        Write-ColorOutput "错误: 安装服务需要指定可执行文件路径" -Color Red
        return $false
    }
    
    if (-not (Test-Path $BinaryPathName)) {
        Write-ColorOutput "错误: 可执行文件不存在: $BinaryPathName" -Color Red
        return $false
    }
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColorOutput "错误: 安装服务需要管理员权限" -Color Red
        return $false
    }
    
    try {
        # 检查服务是否已存在
        $existingService = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-ColorOutput "服务已存在: $Name" -Color Yellow
            
            if (-not $Force) {
                $title = "确认覆盖服务"
                $message = "服务已存在，确定要覆盖吗？"
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "覆盖服务"
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
                $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                $result = $host.ui.PromptForChoice($title, $message, $options, 1)
                
                if ($result -ne 0) {
                    Write-ColorOutput "操作已取消" -Color Yellow
                    return $false
                }
            }
            
            # 删除现有服务
            Stop-ServiceEx -Name $Name | Out-Null
            sc.exe delete $Name | Out-Null
        }
        
        # 创建新服务
        $cmd = "sc.exe create `"$Name`" binPath= `"$BinaryPathName`""
        
        if ($DisplayName) {
            $cmd += " DisplayName= `"$DisplayName`""
        }
        
        if ($StartType) {
            $cmd += " start= $StartType"
        }
        
        Invoke-Expression $cmd
        
        if ($Description) {
            sc.exe description $Name $Description | Out-Null
        }
        
        Write-ColorOutput "服务安装成功: $Name" -Color Green
        return $true
        
    } catch {
        Write-ColorOutput "服务安装失败: $Name - $($_.Exception.Message)" -Color Red
        Write-Log "服务安装失败: $Name - $($_.Exception.Message)"
        return $false
    }
}

function Uninstall-ServiceEx {
    param([string]$Name)
    
    Write-Log "卸载服务: $Name"
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColorOutput "错误: 卸载服务需要管理员权限" -Color Red
        return $false
    }
    
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-ColorOutput "服务不存在: $Name" -Color Yellow
        return $true
    }
    
    try {
        # 停止服务
        Stop-ServiceEx -Name $Name | Out-Null
        
        # 删除服务
        sc.exe delete $Name
        
        Write-ColorOutput "服务卸载成功: $Name" -Color Green
        return $true
        
    } catch {
        Write-ColorOutput "服务卸载失败: $Name - $($_.Exception.Message)" -Color Red
        Write-Log "服务卸载失败: $Name - $($_.Exception.Message)"
        return $false
    }
}

function Backup-Services {
    param([string]$BackupPath)
    
    Write-Log "备份服务配置..."
    
    # 创建备份目录
    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BackupPath "services-$timestamp.csv"
    
    try {
        # 获取所有服务
        $services = Get-CimInstance -ClassName Win32_Service
        
        # 导出服务配置
        $services | Select-Object Name, DisplayName, Description, PathName, StartMode, StartName, State, ServiceType | Export-Csv -Path $backupFile -NoTypeInformation
        
        Write-ColorOutput "服务配置备份完成: $backupFile" -Color Green
        Write-Log "服务配置备份完成: $backupFile"
        
        # 备份特定重要服务的配置
        $importantServices = @("EventLog", "PlugPlay", "RpcSs", "Winmgmt", "BITS", "wuauserv")
        $importantBackupFile = Join-Path $BackupPath "important-services-$timestamp.csv"
        
        $importantServiceConfigs = $services | Where-Object { $importantServices -contains $_.Name }
        $importantServiceConfigs | Select-Object Name, DisplayName, Description, PathName, StartMode, StartName, State, ServiceType | Export-Csv -Path $importantBackupFile -NoTypeInformation
        
        Write-Log "重要服务配置备份完成: $importantBackupFile"
        
        return $backupFile
        
    } catch {
        Write-ColorOutput "备份失败: $($_.Exception.Message)" -Color Red
        Write-Log "备份失败: $($_.Exception.Message)"
        throw
    }
}

function Restore-Services {
    param([string]$BackupFile)
    
    Write-Log "恢复服务配置..."
    
    if (-not (Test-Path $BackupFile)) {
        Write-ColorOutput "备份文件不存在: $BackupFile" -Color Red
        throw "备份文件不存在: $BackupFile"
    }
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColorOutput "错误: 恢复服务配置需要管理员权限" -Color Red
        return $false
    }
    
    try {
        # 导入服务配置
        $services = Import-Csv -Path $BackupFile
        
        foreach ($service in $services) {
            $existingService = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            
            if ($existingService) {
                Write-Log "恢复服务配置: $($service.Name)"
                
                # 恢复启动类型
                $startType = switch ($service.StartMode) {
                    "Auto" { "Automatic" }
                    "Manual" { "Manual" }
                    "Disabled" { "Disabled" }
                    default { "Manual" }
                }
                
                Set-Service -Name $service.Name -StartupType $startType
                
                # 恢复显示名称和描述
                $serviceConfig = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'"
                $serviceConfig.DisplayName = $service.DisplayName
                $serviceConfig.Description = $service.Description
                $serviceConfig | Set-CimInstance
                
                Write-Log "服务配置已恢复: $($service.Name)"
            }
        }
        
        Write-ColorOutput "服务配置恢复完成" -Color Green
        return $true
        
    } catch {
        Write-ColorOutput "恢复失败: $($_.Exception.Message)" -Color Red
        Write-Log "恢复失败: $($_.Exception.Message)"
        throw
    }
}

# 主程序
try {
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "      Windows服务管理工具" -Color Cyan
    Write-ColorOutput "======================================" -Color Cyan
    
    Write-Log "开始服务管理..."
    Write-Log "命令: $Command"
    
    # 执行命令
    switch ($Command) {
        "list" {
            List-Services
        }
        
        "start" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 启动命令需要指定服务名" -Color Red
                exit 1
            }
            Start-ServiceEx -Name $ServiceName
        }
        
        "stop" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 停止命令需要指定服务名" -Color Red
                exit 1
            }
            Stop-ServiceEx -Name $ServiceName
        }
        
        "restart" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 重启命令需要指定服务名" -Color Red
                exit 1
            }
            Restart-ServiceEx -Name $ServiceName
        }
        
        "status" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 状态命令需要指定服务名" -Color Red
                exit 1
            }
            Get-ServiceStatus -Name $ServiceName
        }
        
        "config" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 配置命令需要指定服务名" -Color Red
                exit 1
            }
            Set-ServiceConfig -Name $ServiceName -StartType $StartType -DisplayName $DisplayName -Description $Description
        }
        
        "install" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 安装命令需要指定服务名" -Color Red
                exit 1
            }
            Install-ServiceEx -Name $ServiceName -DisplayName $DisplayName -Description $Description -BinaryPathName $BinaryPathName -StartType $StartType
        }
        
        "uninstall" {
            if (-not $ServiceName) {
                Write-ColorOutput "错误: 卸载命令需要指定服务名" -Color Red
                exit 1
            }
            Uninstall-ServiceEx -Name $ServiceName
        }
        
        "backup" {
            Backup-Services -BackupPath $BackupPath
        }
        
        "restore" {
            if (-not $RestoreFile) {
                Write-ColorOutput "错误: 恢复命令需要指定备份文件" -Color Red
                exit 1
            }
            Restore-Services -BackupFile $RestoreFile
        }
    }
    
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "服务管理完成!" -Color Green
    Write-ColorOutput "日志文件: $LogFile" -Color Green
    
} catch {
    Write-ColorOutput "错误: $($_.Exception.Message)" -Color Red
    Write-Log "错误: $($_.Exception.Message)"
    exit 1
}