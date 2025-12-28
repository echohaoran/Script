# Windows进程监控脚本
# 功能：监控系统进程，检测异常进程和资源使用情况
# 使用方法：.\process-monitor.ps1 [选项]

param(
    [int]$Interval = 10,
    [int]$CpuThreshold = 80,
    [int]$MemoryThreshold = 80,
    [int]$Duration = 0,  # 0表示无限运行
    [string]$LogPath = "$env:TEMP",
    [string]$ReportPath = "$env:USERPROFILE\Desktop",
    [switch]$Daemon = $false,
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
$LogFile = Join-Path $LogPath "process-monitor-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$ReportFile = Join-Path $ReportPath "process-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Write-Log {
    param([string]$Message)
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    if ($Verbose) {
        Write-Host $LogEntry
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

function Get-ProcessCpuUsage {
    param([int]$ProcessId)
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            return $process.CPU
        }
    } catch {
        # 忽略错误
    }
    
    return 0
}

function Get-ProcessMemoryUsage {
    param([int]$ProcessId)
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            $totalMemory = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory
            $processMemory = $process.WorkingSet64
            return [math]::Round(($processMemory / $totalMemory) * 100, 2)
        }
    } catch {
        # 忽略错误
    }
    
    return 0
}

function Get-HighCpuProcesses {
    Write-Log "检查高CPU使用率进程..."
    
    $highCpuProcesses = @()
    $processes = Get-Process | Where-Object { $_.Id -ne 0 } | Sort-Object CPU -Descending
    
    foreach ($process in $processes) {
        $cpuUsage = 0
        
        # 尝试获取CPU使用率百分比
        try {
            $cpuCounter = Get-Counter "\Process($($process.ProcessName))\% Processor Time" -ErrorAction SilentlyContinue
            if ($cpuCounter) {
                $cpuUsage = $cpuCounter.CounterSamples.CookedValue
            }
        } catch {
            # 如果获取不到，使用CPU时间作为参考
            $cpuUsage = $process.CPU
        }
        
        if ($cpuUsage -gt $CpuThreshold) {
            $memoryUsage = Get-ProcessMemoryUsage -ProcessId $process.Id
            
            $processInfo = @{
                Id = $process.Id
                Name = $process.ProcessName
                CpuUsage = [math]::Round($cpuUsage, 2)
                MemoryUsage = $memoryUsage
                WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
                StartTime = $process.StartTime
                Path = $process.Path
                UserName = (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($process.Id)").GetOwner().User
            }
            
            $highCpuProcesses += $processInfo
            
            if ($Verbose) {
                Write-ColorOutput "  高CPU进程: $($process.Name) (ID: $($process.Id)) - CPU: $([math]::Round($cpuUsage, 2))%" -Color Red
            }
        }
    }
    
    return $highCpuProcesses
}

function Get-HighMemoryProcesses {
    Write-Log "检查高内存使用率进程..."
    
    $highMemoryProcesses = @()
    $processes = Get-Process | Where-Object { $_.Id -ne 0 } | Sort-Object WorkingSet64 -Descending
    
    foreach ($process in $processes) {
        $memoryUsage = Get-ProcessMemoryUsage -ProcessId $process.Id
        
        if ($memoryUsage -gt $MemoryThreshold) {
            $cpuUsage = 0
            
            try {
                $cpuCounter = Get-Counter "\Process($($process.ProcessName))\% Processor Time" -ErrorAction SilentlyContinue
                if ($cpuCounter) {
                    $cpuUsage = $cpuCounter.CounterSamples.CookedValue
                }
            } catch {
                $cpuUsage = $process.CPU
            }
            
            $processInfo = @{
                Id = $process.Id
                Name = $process.ProcessName
                CpuUsage = [math]::Round($cpuUsage, 2)
                MemoryUsage = $memoryUsage
                WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
                StartTime = $process.StartTime
                Path = $process.Path
                UserName = (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($process.Id)").GetOwner().User
            }
            
            $highMemoryProcesses += $processInfo
            
            if ($Verbose) {
                Write-ColorOutput "  高内存进程: $($process.Name) (ID: $($process.Id)) - 内存: $memoryUsage%" -Color Red
            }
        }
    }
    
    return $highMemoryProcesses
}

function Get-ZombieProcesses {
    Write-Log "检查僵尸进程..."
    
    # Windows没有真正的僵尸进程，但可以检查无响应的进程
    $zombieProcesses = @()
    $processes = Get-Process | Where-Object { $_.Responding -eq $false }
    
    foreach ($process in $processes) {
        $processInfo = @{
            Id = $process.Id
            Name = $process.ProcessName
            StartTime = $process.StartTime
            Path = $process.Path
            Responding = $process.Responding
        }
        
        $zombieProcesses += $processInfo
        
        if ($Verbose) {
            Write-ColorOutput "  无响应进程: $($process.Name) (ID: $($process.Id))" -Color Yellow
        }
    }
    
    return $zombieProcesses
}

function Get-SystemLoad {
    Write-Log "检查系统负载..."
    
    $systemLoad = @{}
    
    # CPU使用率
    $cpuUsage = Get-Counter "\Processor(_Total)\% Processor Time"
    $systemLoad.CpuUsage = [math]::Round($cpuUsage.CounterSamples.CookedValue, 2)
    
    # 内存使用情况
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemory = $os.TotalVisibleMemorySize
    $freeMemory = $os.FreePhysicalMemory
    $systemLoad.MemoryUsage = [math]::Round((($totalMemory - $freeMemory) / $totalMemory) * 100, 2)
    
    # 磁盘使用率
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    $systemLoad.DiskUsage = @()
    
    foreach ($disk in $disks) {
        $diskInfo = @{
            Drive = $disk.DeviceID
            TotalSize = [math]::Round($disk.Size / 1GB, 2)
            FreeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
            UsagePercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
        }
        
        $systemLoad.DiskUsage += $diskInfo
    }
    
    return $systemLoad
}

function Get-ProcessCount {
    Write-Log "统计进程数量..."
    
    $processCount = @{}
    
    # 总进程数
    $processCount.Total = (Get-Process).Count
    
    # 按状态分类
    $processCount.Running = (Get-Process | Where-Object { $_.Responding -eq $true }).Count
    $processCount.NotResponding = (Get-Process | Where-Object { $_.Responding -eq $false }).Count
    
    # 按用户统计
    $processesByUser = @{}
    $processes = Get-CimInstance -ClassName Win32_Process
    
    foreach ($process in $processes) {
        try {
            $owner = $process.GetOwner()
            $user = "$($owner.Domain)\$($owner.User)"
            
            if (-not $processesByUser.ContainsKey($user)) {
                $processesByUser[$user] = 0
            }
            
            $processesByUser[$user]++
        } catch {
            # 忽略无法获取所有者的进程
        }
    }
    
    $processCount.ByUser = $processesByUser
    
    return $processCount
}

function Monitor-Loop {
    param([int]$Duration)
    
    Write-ColorOutput "开始监控循环... (按Ctrl+C停止)" -Color Green
    
    $startTime = Get-Date
    $monitoring = $true
    
    try {
        while ($monitoring) {
            $currentTime = Get-Date
            
            Write-Log "监控时间: $currentTime"
            Write-Log "----------------------------------------"
            
            # 系统负载
            $systemLoad = Get-SystemLoad
            Write-Log "系统负载:"
            Write-Log "  CPU使用率: $($systemLoad.CpuUsage)%"
            Write-Log "  内存使用率: $($systemLoad.MemoryUsage)%"
            
            foreach ($disk in $systemLoad.DiskUsage) {
                Write-Log "  磁盘 $($disk.Drive): $($disk.UsagePercent)% (可用: $($disk.FreeSpace)GB)"
            }
            
            # 高CPU进程
            $highCpuProcesses = Get-HighCpuProcesses
            if ($highCpuProcesses.Count -gt 0) {
                Write-Log "高CPU使用率进程 ($CpuThreshold%):"
                foreach ($process in $highCpuProcesses) {
                    Write-Log "  $($process.Name) (ID: $($process.Id)) - CPU: $($process.CpuUsage)%, 内存: $($process.MemoryUsage)%"
                }
            } else {
                Write-Log "无高CPU使用率进程"
            }
            
            # 高内存进程
            $highMemoryProcesses = Get-HighMemoryProcesses
            if ($highMemoryProcesses.Count -gt 0) {
                Write-Log "高内存使用率进程 ($MemoryThreshold%):"
                foreach ($process in $highMemoryProcesses) {
                    Write-Log "  $($process.Name) (ID: $($process.Id)) - 内存: $($process.MemoryUsage)%, CPU: $($process.CpuUsage)%"
                }
            } else {
                Write-Log "无高内存使用率进程"
            }
            
            # 僵尸进程
            $zombieProcesses = Get-ZombieProcesses
            if ($zombieProcesses.Count -gt 0) {
                Write-Log "无响应进程:"
                foreach ($process in $zombieProcesses) {
                    Write-Log "  $($process.Name) (ID: $($process.Id))"
                }
            } else {
                Write-Log "无无响应进程"
            }
            
            # 进程统计
            $processCount = Get-ProcessCount
            Write-Log "进程统计:"
            Write-Log "  总进程数: $($processCount.Total)"
            Write-Log "  运行中: $($processCount.Running)"
            Write-Log "  无响应: $($processCount.NotResponding)"
            
            Write-Log "========================================"
            Write-Log "下次检查时间: $(Get-Date).AddSeconds($Interval)"
            Write-Log ""
            
            # 检查是否达到持续时间
            if ($Duration -gt 0 -and ($currentTime - $startTime).TotalSeconds -ge $Duration) {
                $monitoring = $false
                break
            }
            
            # 等待下次检查
            Start-Sleep -Seconds $Interval
        }
    } catch [System.Management.Automation.HaltCommandException] {
        Write-Log "收到中断信号，正在退出..."
        $monitoring = $false
    }
}

function Single-Monitor {
    Write-Log "执行单次进程监控..."
    
    # 系统负载
    $systemLoad = Get-SystemLoad
    
    # 高CPU进程
    $highCpuProcesses = Get-HighCpuProcesses
    
    # 高内存进程
    $highMemoryProcesses = Get-HighMemoryProcesses
    
    # 僵尸进程
    $zombieProcesses = Get-ZombieProcesses
    
    # 进程统计
    $processCount = Get-ProcessCount
    
    # 生成报告
    $report = @()
    $report += "=" * 60
    $report += "        进程监控报告"
    $report += "=" * 60
    $report += "生成时间: $(Get-Date)"
    $report += ""
    
    $report += "==== 系统负载 ===="
    $report += "CPU使用率: $($systemLoad.CpuUsage)%"
    $report += "内存使用率: $($systemLoad.MemoryUsage)%"
    
    foreach ($disk in $systemLoad.DiskUsage) {
        $report += "磁盘 $($disk.Drive): $($disk.UsagePercent)% (可用: $($disk.FreeSpace)GB)"
    }
    $report += ""
    
    $report += "==== 高CPU使用率进程 ===="
    if ($highCpuProcesses.Count -gt 0) {
        foreach ($process in $highCpuProcesses) {
            $report += "$($process.Name) (ID: $($process.Id)) - CPU: $($process.CpuUsage)%, 内存: $($process.MemoryUsage)%"
            $report += "  用户: $($process.UserName)"
            $report += "  路径: $($process.Path)"
            $report += "  启动时间: $($process.StartTime)"
            $report += ""
        }
    } else {
        $report += "无高CPU使用率进程"
    }
    $report += ""
    
    $report += "==== 高内存使用率进程 ===="
    if ($highMemoryProcesses.Count -gt 0) {
        foreach ($process in $highMemoryProcesses) {
            $report += "$($process.Name) (ID: $($process.Id)) - 内存: $($process.MemoryUsage)%, CPU: $($process.CpuUsage)%"
            $report += "  用户: $($process.UserName)"
            $report += "  路径: $($process.Path)"
            $report += "  启动时间: $($process.StartTime)"
            $report += ""
        }
    } else {
        $report += "无高内存使用率进程"
    }
    $report += ""
    
    $report += "==== 无响应进程 ===="
    if ($zombieProcesses.Count -gt 0) {
        foreach ($process in $zombieProcesses) {
            $report += "$($process.Name) (ID: $($process.Id))"
            $report += "  路径: $($process.Path)"
            $report += "  启动时间: $($process.StartTime)"
            $report += ""
        }
    } else {
        $report += "无无响应进程"
    }
    $report += ""
    
    $report += "==== 进程统计 ===="
    $report += "总进程数: $($processCount.Total)"
    $report += "运行中: $($processCount.Running)"
    $report += "无响应: $($processCount.NotResponding)"
    $report += ""
    $report += "按用户统计:"
    foreach ($user in $processCount.ByUser.GetEnumerator()) {
        $report += "  $($user.Key): $($user.Value)"
    }
    
    # 写入报告文件
    $report | Out-File -FilePath $ReportFile -Encoding UTF8
    
    Write-ColorOutput "报告已生成: $ReportFile" -Color Green
}

# 主程序
try {
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "      Windows进程监控工具" -Color Cyan
    Write-ColorOutput "======================================" -Color Cyan
    
    Write-Log "开始进程监控..."
    Write-Log "监控间隔: ${Interval}秒"
    Write-Log "CPU阈值: ${CpuThreshold}%"
    Write-Log "内存阈值: ${MemoryThreshold}%"
    Write-Log "守护进程模式: $Daemon"
    Write-Log "详细输出: $Verbose"
    
    # 检查输出目录
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    
    if (-not (Test-Path $ReportPath)) {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    }
    
    # 执行监控
    if ($Daemon) {
        Monitor-Loop -Duration $Duration
    } else {
        Single-Monitor
    }
    
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "进程监控完成!" -Color Green
    Write-ColorOutput "日志文件: $LogFile" -Color Green
    
} catch {
    Write-ColorOutput "错误: $($_.Exception.Message)" -Color Red
    Write-Log "错误: $($_.Exception.Message)"
    exit 1
}