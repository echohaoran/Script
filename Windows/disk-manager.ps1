# Windows磁盘管理脚本
# 功能：分析、清理和管理磁盘空间
# 使用方法：.\disk-manager.ps1 [命令] [选项]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("analyze", "cleanup", "duplicate", "bigfiles", "defrag", "check", "partition")]
    [string]$Command,
    
    [string]$Drive = "C:",
    [string]$Path,
    [string]$SearchPath,
    [int]$SizeThreshold = 100,
    [string]$ReportPath = "$env:USERPROFILE\Desktop",
    [switch]$Recurse,
    [switch]$Force,
    [switch]$Verbose,
    [switch]$WhatIf
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
$LogFile = Join-Path $env:TEMP "disk-manager-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message)
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    
    if ($Verbose) {
        Write-Host $LogEntry
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

function Get-DiskInfo {
    param([string]$Drive)
    
    Write-Log "获取磁盘信息: $Drive"
    
    try {
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$Drive'"
        
        if ($disk) {
            $diskInfo = @{
                Drive = $disk.DeviceID
                VolumeName = $disk.VolumeName
                FileSystem = $disk.FileSystem
                TotalSize = [math]::Round($disk.Size / 1GB, 2)
                FreeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
                UsedSpace = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                UsagePercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
                VolumeSerialNumber = $disk.VolumeSerialNumber
                DriveType = switch ($disk.DriveType) {
                    2 { "可移动磁盘" }
                    3 { "本地磁盘" }
                    4 { "网络驱动器" }
                    5 { "光盘" }
                    default { "未知" }
                }
            }
            
            return $diskInfo
        }
    } catch {
        Write-Log "获取磁盘信息失败: $($_.Exception.Message)"
    }
    
    return $null
}

function Analyze-Disk {
    param([string]$Drive)
    
    Write-Log "分析磁盘: $Drive"
    
    $diskInfo = Get-DiskInfo -Drive $Drive
    if (-not $diskInfo) {
        Write-ColorOutput "无法获取磁盘信息: $Drive" -Color Red
        return
    }
    
    Write-ColorOutput "磁盘信息:" -Color Cyan
    Write-ColorOutput "  驱动器: $($diskInfo.Drive)" -Color White
    Write-ColorOutput "  卷标: $($diskInfo.VolumeName)" -Color White
    Write-ColorOutput "  文件系统: $($diskInfo.FileSystem)" -Color White
    Write-ColorOutput "  总容量: $($diskInfo.TotalSize) GB" -Color White
    Write-ColorOutput "  已用空间: $($diskInfo.UsedSpace) GB" -Color White
    Write-ColorOutput "  可用空间: $($diskInfo.FreeSpace) GB" -Color White
    Write-ColorOutput "  使用率: $($diskInfo.UsagePercent)%" -Color White
    Write-ColorOutput "  驱动器类型: $($diskInfo.DriveType)" -Color White
    
    # 分析目录大小
    Write-ColorOutput "`n分析目录大小..." -Color Cyan
    
    $analysisPath = "${Drive}\"
    $directories = @(
        "Windows",
        "Program Files",
        "Program Files (x86)",
        "Users",
        "ProgramData"
    )
    
    foreach ($dir in $directories) {
        $fullPath = Join-Path $analysisPath $dir
        if (Test-Path $fullPath) {
            try {
                $size = (Get-ChildItem -Path $fullPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                $sizeGB = [math]::Round($size / 1GB, 2)
                
                Write-ColorOutput "  $dir`: $sizeGB GB" -Color White
            } catch {
                Write-ColorOutput "  $dir`: 无法计算大小" -Color Yellow
            }
        }
    }
    
    # 检查磁盘健康状态
    Write-ColorOutput "`n检查磁盘健康状态..." -Color Cyan
    
    try {
        $volume = Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter='$Drive'"
        $defragAnalysis = Invoke-CimMethod -InputObject $volume -MethodName DefragAnalysis
        
        Write-ColorOutput "  碎片率: $($defragAnalysis.DefragAnalysis.TotalPercentFragmentation)%" -Color White
        Write-ColorOutput "  建议碎片整理: $(if ($defragAnalysis.DefragAnalysis.TotalPercentFragmentation -gt 10) { '是' } else { '否' })" -Color White
        
    } catch {
        Write-ColorOutput "  无法获取碎片信息" -Color Yellow
    }
    
    return $diskInfo
}

function Clean-Disk {
    param([string]$Drive)
    
    Write-Log "清理磁盘: $Drive"
    
    # 确认清理
    if (-not $Force) {
        $title = "确认磁盘清理"
        $message = "确定要清理磁盘 $Drive 吗？`n`n此操作将删除临时文件、回收站文件、系统更新缓存等。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "清理磁盘"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    $cleanedSize = 0
    
    try {
        # 清理临时文件
        Write-Log "清理临时文件..."
        
        $tempPaths = @(
            "$env:TEMP",
            "$env:WINDIR\Temp",
            "${Drive}\Windows\Prefetch",
            "${Drive}\Windows\SoftwareDistribution\Download"
        )
        
        foreach ($tempPath in $tempPaths) {
            if (Test-Path $tempPath) {
                $files = Get-ChildItem -Path $tempPath -Recurse -ErrorAction SilentlyContinue
                
                foreach ($file in $files) {
                    try {
                        $size = (Get-Item $file.FullName).Length
                        $cleanedSize += $size
                        
                        if (-not $WhatIf) {
                            Remove-Item -Path $file.FullName -Recurse -Force
                        }
                        
                        if ($Verbose) {
                            Write-Log "删除: $($file.FullName)"
                        }
                    } catch {
                        Write-Log "删除失败: $($file.FullName)"
                    }
                }
            }
        }
        
        # 清理回收站
        Write-Log "清理回收站..."
        
        try {
            $recycleBin = New-Object -ComObject Shell.Application
            $recycleBinItems = $recycleBin.NameSpace(10).Items()
            
            foreach ($item in $recycleBinItems) {
                $size = $item.Size
                $cleanedSize += $size
                
                if (-not $WhatIf) {
                    $item.InvokeVerb("Delete")
                }
                
                if ($Verbose) {
                    Write-Log "删除回收站项: $($item.Name)"
                }
            }
        } catch {
            Write-Log "清理回收站失败"
        }
        
        # 清理系统更新缓存
        Write-Log "清理系统更新缓存..."
        
        try {
            if (-not $WhatIf) {
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "${Drive}\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "清理系统更新缓存失败"
        }
        
        # 清理浏览器缓存
        Write-Log "清理浏览器缓存..."
        
        $browserPaths = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"
        )
        
        foreach ($browserPath in $browserPaths) {
            $paths = Resolve-Path -Path $browserPath -ErrorAction SilentlyContinue
            
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    $files = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
                    
                    foreach ($file in $files) {
                        try {
                            $size = (Get-Item $file.FullName).Length
                            $cleanedSize += $size
                            
                            if (-not $WhatIf) {
                                Remove-Item -Path $file.FullName -Recurse -Force
                            }
                            
                            if ($Verbose) {
                                Write-Log "删除浏览器缓存: $($file.FullName)"
                            }
                        } catch {
                            Write-Log "删除浏览器缓存失败: $($file.FullName)"
                        }
                    }
                }
            }
        }
        
        $cleanedSizeGB = [math]::Round($cleanedSize / 1GB, 2)
        Write-ColorOutput "磁盘清理完成，释放了 $cleanedSizeGB GB 空间" -Color Green
        Write-Log "磁盘清理完成，释放了 $cleanedSizeGB GB 空间"
        
    } catch {
        Write-ColorOutput "清理失败: $($_.Exception.Message)" -Color Red
        Write-Log "清理失败: $($_.Exception.Message)"
        throw
    }
}

function Find-DuplicateFiles {
    param([string]$SearchPath)
    
    Write-Log "查找重复文件: $SearchPath"
    
    if (-not (Test-Path $SearchPath)) {
        Write-ColorOutput "路径不存在: $SearchPath" -Color Red
        return
    }
    
    try {
        # 获取所有文件
        Write-Log "扫描文件..."
        $files = Get-ChildItem -Path $SearchPath -Recurse -File -ErrorAction SilentlyContinue
        
        # 按大小分组
        $sizeGroups = $files | Group-Object -Property Length
        
        # 查找重复文件
        $duplicateGroups = @()
        
        foreach ($group in $sizeGroups) {
            if ($group.Count -gt 1 -and $group.Name -gt 0) {
                $hashes = @{}
                
                foreach ($file in $group.Group) {
                    try {
                        $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
                        
                        if (-not $hashes.ContainsKey($hash)) {
                            $hashes[$hash] = @()
                        }
                        
                        $hashes[$hash] += $file
                    } catch {
                        Write-Log "计算哈希失败: $($file.FullName)"
                    }
                }
                
                foreach ($hash in $hashes.Keys) {
                    if ($hashes[$hash].Count -gt 1) {
                        $duplicateGroups += $hashes[$hash]
                    }
                }
            }
        }
        
        # 输出结果
        if ($duplicateGroups.Count -gt 0) {
            Write-ColorOutput "找到 $($duplicateGroups.Count) 组重复文件:" -Color Green
            
            foreach ($group in $duplicateGroups) {
                Write-ColorOutput "重复组 (大小: $([math]::Round($group[0].Length / 1MB, 2)) MB):" -Color Cyan
                
                foreach ($file in $group) {
                    Write-ColorOutput "  $($file.FullName)" -Color White
                }
                
                Write-Host ""
            }
            
            # 生成报告
            $reportFile = Join-Path $ReportPath "duplicate-files-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            
            $report = @()
            $report += "重复文件报告"
            $report += "生成时间: $(Get-Date)"
            $report += "搜索路径: $SearchPath"
            $report += "重复组数: $($duplicateGroups.Count)"
            $report += ""
            
            foreach ($group in $duplicateGroups) {
                $report += "重复组 (大小: $([math]::Round($group[0].Length / 1MB, 2)) MB):"
                
                foreach ($file in $group) {
                    $report += "  $($file.FullName)"
                }
                
                $report += ""
            }
            
            $report | Out-File -FilePath $reportFile -Encoding UTF8
            Write-ColorOutput "报告已保存: $reportFile" -Color Green
            
        } else {
            Write-ColorOutput "未找到重复文件" -Color Yellow
        }
        
    } catch {
        Write-ColorOutput "查找重复文件失败: $($_.Exception.Message)" -Color Red
        Write-Log "查找重复文件失败: $($_.Exception.Message)"
        throw
    }
}

function Find-BigFiles {
    param(
        [string]$SearchPath,
        [int]$SizeThreshold
    )
    
    Write-Log "查找大文件: $SearchPath (阈值: ${SizeThreshold}MB)"
    
    if (-not (Test-Path $SearchPath)) {
        Write-ColorOutput "路径不存在: $SearchPath" -Color Red
        return
    }
    
    try {
        # 获取所有文件
        Write-Log "扫描文件..."
        $files = Get-ChildItem -Path $SearchPath -Recurse -File -ErrorAction SilentlyContinue
        
        # 筛选大文件
        $bigFiles = $files | Where-Object { $_.Length -gt ($SizeThreshold * 1MB) } | Sort-Object Length -Descending
        
        # 输出结果
        if ($bigFiles.Count -gt 0) {
            Write-ColorOutput "找到 $($bigFiles.Count) 个大文件 (>${SizeThreshold}MB):" -Color Green
            
            foreach ($file in $bigFiles) {
                $sizeMB = [math]::Round($file.Length / 1MB, 2)
                Write-ColorOutput "  $($file.FullName) - $sizeMB MB" -Color White
            }
            
            # 生成报告
            $reportFile = Join-Path $ReportPath "big-files-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            
            $report = @()
            $report += "大文件报告"
            $report += "生成时间: $(Get-Date)"
            $report += "搜索路径: $SearchPath"
            $report += "大小阈值: ${SizeThreshold}MB"
            $report += "大文件数: $($bigFiles.Count)"
            $report += ""
            
            foreach ($file in $bigFiles) {
                $sizeMB = [math]::Round($file.Length / 1MB, 2)
                $report += "$($file.FullName) - $sizeMB MB"
            }
            
            $report | Out-File -FilePath $reportFile -Encoding UTF8
            Write-ColorOutput "报告已保存: $reportFile" -Color Green
            
        } else {
            Write-ColorOutput "未找到大文件" -Color Yellow
        }
        
    } catch {
        Write-ColorOutput "查找大文件失败: $($_.Exception.Message)" -Color Red
        Write-Log "查找大文件失败: $($_.Exception.Message)"
        throw
    }
}

function Defrag-Disk {
    param([string]$Drive)
    
    Write-Log "碎片整理磁盘: $Drive"
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColorOutput "错误: 磁盘碎片整理需要管理员权限" -Color Red
        return
    }
    
    # 确认碎片整理
    if (-not $Force) {
        $title = "确认磁盘碎片整理"
        $message = "确定要对磁盘 $Drive 进行碎片整理吗？`n`n此过程可能需要较长时间。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "碎片整理"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    try {
        Write-ColorOutput "开始磁盘碎片整理..." -Color Cyan
        
        # 检查是否为SSD
        $disk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -like "*$($Drive.TrimEnd(':'))*" }
        
        if ($disk -and $disk.MediaType -eq "SSD") {
            Write-ColorOutput "检测到SSD，无需进行碎片整理" -Color Yellow
            return
        }
        
        # 执行碎片整理
        if (-not $WhatIf) {
            $volume = Get-Volume -DriveLetter $Drive.TrimEnd(':')
            $defragJob = Start-Job -ScriptBlock {
                param($DriveLetter)
                Optimize-Volume -DriveLetter $DriveLetter -Defrag -Verbose
            } -ArgumentList $Drive.TrimEnd(':')
            
            # 显示进度
            while ($defragJob.State -eq "Running") {
                Write-Host "." -NoNewline
                Start-Sleep -Seconds 5
            }
            
            Write-Host ""
            
            # 获取结果
            $result = Receive-Job -Job $defragJob
            Remove-Job -Job $defragJob
            
            Write-ColorOutput "磁盘碎片整理完成" -Color Green
        } else {
            Write-ColorOutput "模拟模式: 磁盘碎片整理" -Color Yellow
        }
        
    } catch {
        Write-ColorOutput "碎片整理失败: $($_.Exception.Message)" -Color Red
        Write-Log "碎片整理失败: $($_.Exception.Message)"
        throw
    }
}

function Check-Disk {
    param([string]$Drive)
    
    Write-Log "检查磁盘: $Drive"
    
    if (-not (Test-AdminPrivileges)) {
        Write-ColorOutput "错误: 磁盘检查需要管理员权限" -Color Red
        return
    }
    
    # 确认磁盘检查
    if (-not $Force) {
        $title = "确认磁盘检查"
        $message = "确定要检查磁盘 $Drive 吗？`n`n此过程可能需要较长时间，建议在系统空闲时执行。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "检查磁盘"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    try {
        Write-ColorOutput "开始磁盘检查..." -Color Cyan
        
        if (-not $WhatIf) {
            # 修复文件系统错误
            Repair-Volume -DriveLetter $Drive.TrimEnd(':') -Scan -Verbose
            
            Write-ColorOutput "磁盘检查完成" -Color Green
        } else {
            Write-ColorOutput "模拟模式: 磁盘检查" -Color Yellow
        }
        
    } catch {
        Write-ColorOutput "磁盘检查失败: $($_.Exception.Message)" -Color Red
        Write-Log "磁盘检查失败: $($_.Exception.Message)"
        throw
    }
}

function Show-PartitionInfo {
    Write-Log "获取分区信息..."
    
    try {
        $disks = Get-Disk
        $partitions = Get-Partition
        
        Write-ColorOutput "磁盘和分区信息:" -Color Cyan
        
        foreach ($disk in $disks) {
            Write-ColorOutput "`n磁盘 $($disk.Number):" -Color White
            Write-ColorOutput "  型号: $($disk.Model)" -Color Gray
            Write-ColorOutput "  总大小: $([math]::Round($disk.Size / 1GB, 2)) GB" -Color Gray
            Write-ColorOutput "  分区样式: $($disk.PartitionStyle)" -Color Gray
            
            $diskPartitions = $partitions | Where-Object { $_.DiskNumber -eq $disk.Number }
            
            foreach ($partition in $diskPartitions) {
                if ($partition.DriveLetter) {
                    $volume = Get-Volume -Partition $partition
                    Write-ColorOutput "  分区 $($partition.PartitionNumber) ($($partition.DriveLetter)): $([math]::Round($partition.Size / 1GB, 2)) GB ($($volume.FileSystem))" -Color Gray
                } else {
                    Write-ColorOutput "  分区 $($partition.PartitionNumber): $([math]::Round($partition.Size / 1GB, 2)) GB (未分配)" -Color Gray
                }
            }
        }
        
    } catch {
        Write-ColorOutput "获取分区信息失败: $($_.Exception.Message)" -Color Red
        Write-Log "获取分区信息失败: $($_.Exception.Message)"
        throw
    }
}

# 主程序
try {
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "      Windows磁盘管理工具" -Color Cyan
    Write-ColorOutput "======================================" -Color Cyan
    
    Write-Log "开始磁盘管理..."
    Write-Log "命令: $Command"
    
    # 检查管理员权限
    if ($Command -in @("cleanup", "defrag", "check") -and -not (Test-AdminPrivileges)) {
        Write-ColorOutput "警告: 某些操作需要管理员权限" -Color Yellow
    }
    
    # 创建报告目录
    if (-not (Test-Path $ReportPath)) {
        New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
    }
    
    # 执行命令
    switch ($Command) {
        "analyze" {
            Analyze-Disk -Drive $Drive
        }
        
        "cleanup" {
            Clean-Disk -Drive $Drive
        }
        
        "duplicate" {
            $searchPath = if ($SearchPath) { $SearchPath } else { $Drive }
            Find-DuplicateFiles -SearchPath $searchPath
        }
        
        "bigfiles" {
            $searchPath = if ($SearchPath) { $SearchPath } else { $Drive }
            Find-BigFiles -SearchPath $searchPath -SizeThreshold $SizeThreshold
        }
        
        "defrag" {
            Defrag-Disk -Drive $Drive
        }
        
        "check" {
            Check-Disk -Drive $Drive
        }
        
        "partition" {
            Show-PartitionInfo
        }
    }
    
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "磁盘管理完成!" -Color Green
    Write-ColorOutput "日志文件: $LogFile" -Color Green
    
} catch {
    Write-ColorOutput "错误: $($_.Exception.Message)" -Color Red
    Write-Log "错误: $($_.Exception.Message)"
    exit 1
}