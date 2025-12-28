# Windows系统信息收集脚本
# 功能：收集Windows系统硬件、软件、网络等信息并生成报告
# 使用方法：.\system-info.ps1 [选项]

param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop",
    [switch]$IncludeHardware = $true,
    [switch]$IncludeSoftware = $true,
    [switch]$IncludeNetwork = $true,
    [switch]$IncludeProcesses = $true,
    [switch]$IncludeServices = $true,
    [switch]$IncludeEvents = $false,
    [switch]$Verbose = $false
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
$LogFile = Join-Path $OutputPath "system-info-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ReportFile = Join-Path $OutputPath "system-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log {
    param([string]$Message)
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    if ($Verbose) {
        Write-Host $LogEntry
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

function Get-SystemBasicInfo {
    Write-Log "收集系统基本信息..."
    
    $info = @{}
    
    # 计算机信息
    $info.ComputerName = $env:COMPUTERNAME
    $info.UserName = $env:USERNAME
    $info.Domain = $env:USERDOMAIN
    
    # 操作系统信息
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $info.OSName = $os.Caption
    $info.OSVersion = $os.Version
    $info.OSBuild = $os.BuildNumber
    $info.InstallDate = $os.InstallDate
    $info.LastBootUpTime = $os.LastBootUpTime
    $info.LocalDateTime = $os.LocalDateTime
    
    # 系统类型
    $info.SystemType = $os.SystemType
    $info.TotalVisibleMemorySize = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $info.FreePhysicalMemory = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    
    # 计算机系统信息
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $info.Manufacturer = $cs.Manufacturer
    $info.Model = $cs.Model
    $info.NumberOfProcessors = $cs.NumberOfProcessors
    $info.TotalPhysicalMemory = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    
    # BIOS信息
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $info.BIOSVersion = $bios.SMBIOSBIOSVersion
    $info.BIOSManufacturer = $bios.Manufacturer
    $info.ReleaseDate = $bios.ReleaseDate
    
    return $info
}

function Get-HardwareInfo {
    Write-Log "收集硬件信息..."
    
    $hardware = @{}
    
    # CPU信息
    $cpu = Get-CimInstance -ClassName Win32_Processor
    $hardware.CPU = @{
        Name = $cpu.Name
        Description = $cpu.Description
        Manufacturer = $cpu.Manufacturer
        NumberOfCores = $cpu.NumberOfCores
        NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
        MaxClockSpeed = $cpu.MaxClockSpeed
        CurrentClockSpeed = $cpu.CurrentClockSpeed
        L2CacheSize = $cpu.L2CacheSize
        L3CacheSize = $cpu.L3CacheSize
    }
    
    # 内存信息
    $memoryModules = Get-CimInstance -ClassName Win32_PhysicalMemory
    $hardware.Memory = @()
    
    foreach ($module in $memoryModules) {
        $hardware.Memory += @{
            DeviceLocator = $module.DeviceLocator
            Capacity = [math]::Round($module.Capacity / 1GB, 2)
            Speed = $module.Speed
            Manufacturer = $module.Manufacturer
            PartNumber = $module.PartNumber
            SerialNumber = $module.SerialNumber
        }
    }
    
    # 磁盘信息
    $disks = Get-CimInstance -ClassName Win32_DiskDrive
    $hardware.Disks = @()
    
    foreach ($disk in $disks) {
        $hardware.Disks += @{
            Model = $disk.Model
            SerialNumber = $disk.SerialNumber
            MediaType = $disk.MediaType
            Size = [math]::Round($disk.Size / 1GB, 2)
            InterfaceType = $disk.InterfaceType
            Partitions = $disk.Partitions
        }
    }
    
    # 显卡信息
    $videoControllers = Get-CimInstance -ClassName Win32_VideoController
    $hardware.Graphics = @()
    
    foreach ($video in $videoControllers) {
        $hardware.Graphics += @{
            Name = $video.Name
            AdapterRAM = [math]::Round($video.AdapterRAM / 1MB, 2)
            DriverVersion = $video.DriverVersion
            VideoProcessor = $video.VideoProcessor
        }
    }
    
    # 主板信息
    $baseboard = Get-CimInstance -ClassName Win32_BaseBoard
    $hardware.Motherboard = @{
        Manufacturer = $baseboard.Manufacturer
        Product = $baseboard.Product
        SerialNumber = $baseboard.SerialNumber
        Version = $baseboard.Version
    }
    
    return $hardware
}

function Get-SoftwareInfo {
    Write-Log "收集软件信息..."
    
    $software = @{}
    
    # 已安装程序
    $installedPrograms = Get-CimInstance -ClassName Win32_Product | Sort-Object Name
    $software.InstalledPrograms = @()
    
    foreach ($program in $installedPrograms) {
        $software.InstalledPrograms += @{
            Name = $program.Name
            Version = $program.Version
            Vendor = $program.Vendor
            InstallDate = $program.InstallDate
            PackageName = $program.PackageName
        }
    }
    
    # Windows功能
    try {
        $windowsFeatures = Get-WindowsOptionalFeature -Online | Where-Object { $_.State -eq "Enabled" } | Sort-Object FeatureName
        $software.WindowsFeatures = @()
        
        foreach ($feature in $windowsFeatures) {
            $software.WindowsFeatures += @{
                FeatureName = $feature.FeatureName
                DisplayName = $feature.DisplayName
                Description = $feature.Description
            }
        }
    } catch {
        Write-Log "获取Windows功能失败: $($_.Exception.Message)"
    }
    
    # 已安装的更新
    try {
        $hotfixes = Get-CimInstance -ClassName Win32_QuickFixEngineering | Sort-Object InstalledOn -Descending
        $software.Hotfixes = @()
        
        foreach ($hotfix in $hotfixes | Select-Object -First 20) {
            $software.Hotfixes += @{
                HotFixID = $hotfix.HotFixID
                Description = $hotfix.Description
                InstalledOn = $hotfix.InstalledOn
                InstalledBy = $hotfix.InstalledBy
            }
        }
    } catch {
        Write-Log "获取更新信息失败: $($_.Exception.Message)"
    }
    
    return $software
}

function Get-NetworkInfo {
    Write-Log "收集网络信息..."
    
    $network = @{}
    
    # 网络适配器
    $adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    $network.Adapters = @()
    
    foreach ($adapter in $adapters) {
        $network.Adapters += @{
            Description = $adapter.Description
            DHCPEnabled = $adapter.DHCPEnabled
            IPAddress = $adapter.IPAddress -join ", "
            SubnetMask = $adapter.IPSubnet -join ", "
            DefaultGateway = $adapter.DefaultIPGateway -join ", "
            DNSServerSearchOrder = $adapter.DNSServerSearchOrder -join ", "
            MACAddress = $adapter.MACAddress
        }
    }
    
    # 网络统计
    $networkStats = Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface
    $network.Statistics = @()
    
    foreach ($stat in $networkStats) {
        $network.Statistics += @{
            Name = $stat.Name
            BytesReceivedPerSec = $stat.BytesReceivedPersec
            BytesSentPerSec = $stat.BytesSentPersec
            CurrentBandwidth = $stat.CurrentBandwidth
        }
    }
    
    # 路由表
    try {
        $routes = Get-NetRoute | Where-Object { $_.DestinationPrefix -ne "0.0.0.0/0" } | Sort-Object RouteMetric
        $network.Routes = @()
        
        foreach ($route in $routes | Select-Object -First 10) {
            $network.Routes += @{
                DestinationPrefix = $route.DestinationPrefix
                NextHop = $route.NextHop
                InterfaceAlias = $route.InterfaceAlias
                RouteMetric = $route.RouteMetric
            }
        }
    } catch {
        Write-Log "获取路由表失败: $($_.Exception.Message)"
    }
    
    return $network
}

function Get-ProcessInfo {
    Write-Log "收集进程信息..."
    
    $processes = Get-Process | Sort-Object CPU -Descending | Select-Object -First 20
    $processInfo = @()
    
    foreach ($process in $processes) {
        try {
            $processInfo += @{
                Name = $process.ProcessName
                ID = $process.Id
                CPU = [math]::Round($process.CPU, 2)
                WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
                PagedMemorySize = [math]::Round($process.PagedMemorySize64 / 1MB, 2)
                StartTime = $process.StartTime
                Path = $process.Path
            }
        } catch {
            Write-Log "获取进程信息失败: $($_.Exception.Message)"
        }
    }
    
    return $processInfo
}

function Get-ServiceInfo {
    Write-Log "收集服务信息..."
    
    # 运行中的服务
    $runningServices = Get-Service | Where-Object { $_.Status -eq "Running" } | Sort-Object Name
    $services = @{
        Running = @()
        Stopped = @()
        Disabled = @()
    }
    
    foreach ($service in $runningServices) {
        $services.Running += @{
            Name = $service.Name
            DisplayName = $service.DisplayName
            StartType = (Get-Service $service.Name).StartType
        }
    }
    
    # 已停止的服务
    $stoppedServices = Get-Service | Where-Object { $_.Status -eq "Stopped" } | Sort-Object Name | Select-Object -First 20
    
    foreach ($service in $stoppedServices) {
        $services.Stopped += @{
            Name = $service.Name
            DisplayName = $service.DisplayName
            StartType = (Get-Service $service.Name).StartType
        }
    }
    
    return $services
}

function Get-EventInfo {
    Write-Log "收集事件日志信息..."
    
    $events = @{}
    
    # 系统错误日志
    try {
        $systemErrors = Get-WinEvent -LogName System -MaxEvents 20 | Where-Object { $_.LevelDisplayName -eq "Error" }
        $events.SystemErrors = @()
        
        foreach ($event in $systemErrors) {
            $events.SystemErrors += @{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                LevelDisplayName = $event.LevelDisplayName
                ProviderName = $event.ProviderName
                Message = ($event.Message -split "`n")[0]
            }
        }
    } catch {
        Write-Log "获取系统错误日志失败: $($_.Exception.Message)"
    }
    
    # 应用程序错误日志
    try {
        $appErrors = Get-WinEvent -LogName Application -MaxEvents 20 | Where-Object { $_.LevelDisplayName -eq "Error" }
        $events.ApplicationErrors = @()
        
        foreach ($event in $appErrors) {
            $events.ApplicationErrors += @{
                TimeCreated = $event.TimeCreated
                Id = $event.Id
                LevelDisplayName = $event.LevelDisplayName
                ProviderName = $event.ProviderName
                Message = ($event.Message -split "`n")[0]
            }
        }
    } catch {
        Write-Log "获取应用程序错误日志失败: $($_.Exception.Message)"
    }
    
    return $events
}

function Generate-Report {
    param(
        [hashtable]$BasicInfo,
        [hashtable]$Hardware,
        [hashtable]$Software,
        [hashtable]$Network,
        [array]$Processes,
        [hashtable]$Services,
        [hashtable]$Events
    )
    
    Write-Log "生成报告..."
    
    # 创建报告内容
    $report = @()
    $report += "=" * 60
    $report += "        Windows系统信息报告"
    $report += "=" * 60
    $report += "生成时间: $(Get-Date)"
    $report += ""
    
    # 基本信息
    $report += "==== 系统基本信息 ===="
    $report += "计算机名: $($BasicInfo.ComputerName)"
    $report += "用户名: $($BasicInfo.UserName)"
    $report += "域名: $($BasicInfo.Domain)"
    $report += "操作系统: $($BasicInfo.OSName)"
    $report += "版本: $($BasicInfo.OSVersion)"
    $report += "构建号: $($BasicInfo.OSBuild)"
    $report += "系统类型: $($BasicInfo.SystemType)"
    $report += "制造商: $($BasicInfo.Manufacturer)"
    $report += "型号: $($BasicInfo.Model)"
    $report += "安装日期: $($BasicInfo.InstallDate)"
    $report += "上次启动: $($BasicInfo.LastBootUpTime)"
    $report += "总内存: $($BasicInfo.TotalPhysicalMemory) GB"
    $report += "可用内存: $($BasicInfo.FreePhysicalMemory) MB"
    $report += ""
    
    # 硬件信息
    if ($IncludeHardware) {
        $report += "==== 硬件信息 ===="
        $report += "CPU: $($Hardware.CPU.Name)"
        $report += "CPU制造商: $($Hardware.CPU.Manufacturer)"
        $report += "CPU核心数: $($Hardware.CPU.NumberOfCores)"
        $report += "CPU逻辑处理器数: $($Hardware.CPU.NumberOfLogicalProcessors)"
        $report += "CPU最大频率: $($Hardware.CPU.MaxClockSpeed) MHz"
        $report += "CPU当前频率: $($Hardware.CPU.CurrentClockSpeed) MHz"
        $report += "L2缓存: $($Hardware.CPU.L2CacheSize) KB"
        $report += "L3缓存: $($Hardware.CPU.L3CacheSize) KB"
        $report += ""
        
        $report += "内存模块:"
        foreach ($module in $Hardware.Memory) {
            $report += "  $($module.DeviceLocator): $($module.Capacity) GB, $($module.Speed) MHz, $($module.Manufacturer)"
        }
        $report += ""
        
        $report += "磁盘驱动器:"
        foreach ($disk in $Hardware.Disks) {
            $report += "  $($disk.Model): $($disk.Size) GB, $($disk.MediaType), $($disk.InterfaceType)"
        }
        $report += ""
        
        $report += "显卡:"
        foreach ($video in $Hardware.Graphics) {
            $report += "  $($video.Name): $($video.AdapterRAM) MB, 驱动版本: $($video.DriverVersion)"
        }
        $report += ""
    }
    
    # 软件信息
    if ($IncludeSoftware) {
        $report += "==== 软件信息 ===="
        $report += "已安装程序数量: $($Software.InstalledPrograms.Count)"
        $report += "最近安装的程序:"
        foreach ($program in $Software.InstalledPrograms | Select-Object -First 10) {
            $report += "  $($program.Name) $($program.Version) - $($program.Vendor)"
        }
        $report += ""
        
        $report += "Windows更新数量: $($Software.Hotfixes.Count)"
        $report += "最近的更新:"
        foreach ($hotfix in $Software.Hotfixes | Select-Object -First 5) {
            $report += "  $($hotfix.HotFixID) - $($hotfix.Description) ($($hotfix.InstalledOn))"
        }
        $report += ""
    }
    
    # 网络信息
    if ($IncludeNetwork) {
        $report += "==== 网络信息 ===="
        $report += "网络适配器:"
        foreach ($adapter in $Network.Adapters) {
            $report += "  $($adapter.Description)"
            $report += "    IP地址: $($adapter.IPAddress)"
            $report += "    子网掩码: $($adapter.SubnetMask)"
            $report += "    默认网关: $($adapter.DefaultGateway)"
            $report += "    DNS服务器: $($adapter.DNSServerSearchOrder)"
            $report += "    MAC地址: $($adapter.MACAddress)"
            $report += "    DHCP: $(if ($adapter.DHCPEnabled) { '启用' } else { '禁用' })"
        }
        $report += ""
    }
    
    # 进程信息
    if ($IncludeProcesses) {
        $report += "==== 进程信息 (前20个) ===="
        $report += "CPU使用率最高的进程:"
        foreach ($process in $Processes) {
            $report += "  $($process.Name) (ID: $($process.ID)): CPU: $($process.CPU)s, 内存: $($process.WorkingSet)MB"
        }
        $report += ""
    }
    
    # 服务信息
    if ($IncludeServices) {
        $report += "==== 服务信息 ===="
        $report += "运行中的服务数量: $($Services.Running.Count)"
        $report += "运行中的服务:"
        foreach ($service in $Services.Running | Select-Object -First 10) {
            $report += "  $($service.Name) - $($service.DisplayName) ($($service.StartType))"
        }
        $report += ""
    }
    
    # 事件信息
    if ($IncludeEvents) {
        $report += "==== 事件日志信息 ===="
        $report += "系统错误日志 (最近20条):"
        foreach ($event in $Events.SystemErrors) {
            $report += "  $($event.TimeCreated) - $($event.ProviderName): $($event.Message)"
        }
        $report += ""
    }
    
    # 写入报告文件
    $report | Out-File -FilePath $ReportFile -Encoding UTF8
    
    Write-ColorOutput "报告已生成: $ReportFile" -Color Green
}

# 主程序
try {
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "      Windows系统信息收集工具" -Color Cyan
    Write-ColorOutput "======================================" -Color Cyan
    
    Write-Log "开始收集系统信息..."
    
    # 检查输出目录
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # 收集信息
    $basicInfo = Get-SystemBasicInfo
    
    $hardware = $null
    if ($IncludeHardware) {
        $hardware = Get-HardwareInfo
    }
    
    $software = $null
    if ($IncludeSoftware) {
        $software = Get-SoftwareInfo
    }
    
    $network = $null
    if ($IncludeNetwork) {
        $network = Get-NetworkInfo
    }
    
    $processes = $null
    if ($IncludeProcesses) {
        $processes = Get-ProcessInfo
    }
    
    $services = $null
    if ($IncludeServices) {
        $services = Get-ServiceInfo
    }
    
    $events = $null
    if ($IncludeEvents) {
        $events = Get-EventInfo
    }
    
    # 生成报告
    Generate-Report -BasicInfo $basicInfo -Hardware $hardware -Software $software -Network $network -Processes $processes -Services $services -Events $events
    
    Write-ColorOutput "系统信息收集完成!" -Color Green
    Write-ColorOutput "日志文件: $LogFile" -Color Green
    
} catch {
    Write-ColorOutput "错误: $($_.Exception.Message)" -Color Red
    Write-Log "错误: $($_.Exception.Message)"
    exit 1
}