# Windows注册表管理脚本
# 功能：管理Windows注册表，包括备份、恢复、清理等操作
# 使用方法：.\registry-manager.ps1 [命令] [选项]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("backup", "restore", "clean", "search", "export", "import", "optimize")]
    [string]$Command,
    
    [string]$Path,
    [string]$BackupPath = "$env:USERPROFILE\Desktop\Registry-Backups",
    [string]$SearchKey,
    [string]$SearchValue,
    [string]$SearchData,
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
$LogFile = Join-Path $env:TEMP "registry-manager-$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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

function Backup-Registry {
    param([string]$BackupPath)
    
    Write-Log "开始备份注册表..."
    
    # 创建备份目录
    if (-not (Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        Write-Log "创建备份目录: $BackupPath"
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # 备份整个注册表
    $backupFile = Join-Path $BackupPath "FullRegistry_$timestamp.reg"
    
    try {
        if (-not $WhatIf) {
            Start-Process -FilePath "reg" -ArgumentList "export", "HKLM", $backupFile, "/y" -Wait -WindowStyle Hidden
            Start-Process -FilePath "reg" -ArgumentList "export", "HKCU", $backupFile, "/y" -Wait -WindowStyle Hidden
        }
        
        Write-ColorOutput "注册表备份完成: $backupFile" -Color Green
        Write-Log "注册表备份完成: $backupFile"
        
        # 备份特定重要键
        $importantKeys = @(
            "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion",
            "HKLM\SYSTEM\CurrentControlSet",
            "HKCU\Software\Microsoft\Windows\CurrentVersion",
            "HKCU\Control Panel"
        )
        
        foreach ($key in $importantKeys) {
            $keyBackupFile = Join-Path $BackupPath "$($key.Replace('\', '_'))_$timestamp.reg"
            
            if (-not $WhatIf) {
                Start-Process -FilePath "reg" -ArgumentList "export", $key, $keyBackupFile, "/y" -Wait -WindowStyle Hidden
            }
            
            Write-Log "备份键: $key -> $keyBackupFile"
        }
        
    } catch {
        Write-ColorOutput "备份失败: $($_.Exception.Message)" -Color Red
        Write-Log "备份失败: $($_.Exception.Message)"
        throw
    }
}

function Restore-Registry {
    param([string]$BackupFile)
    
    Write-Log "开始恢复注册表..."
    
    if (-not (Test-Path $BackupFile)) {
        Write-ColorOutput "备份文件不存在: $BackupFile" -Color Red
        throw "备份文件不存在: $BackupFile"
    }
    
    # 确认恢复
    if (-not $Force) {
        $title = "确认注册表恢复"
        $message = "确定要从以下文件恢复注册表吗？`n`n$BackupFile`n`n警告：此操作不可逆，请确保已创建当前注册表的备份。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "恢复注册表"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    try {
        if (-not $WhatIf) {
            Start-Process -FilePath "reg" -ArgumentList "import", $BackupFile -Wait -Verb RunAs
        }
        
        Write-ColorOutput "注册表恢复完成: $BackupFile" -Color Green
        Write-Log "注册表恢复完成: $BackupFile"
        
    } catch {
        Write-ColorOutput "恢复失败: $($_.Exception.Message)" -Color Red
        Write-Log "恢复失败: $($_.Exception.Message)"
        throw
    }
}

function Search-Registry {
    param(
        [string]$SearchKey,
        [string]$SearchValue,
        [string]$SearchData,
        [bool]$Recurse
    )
    
    Write-Log "搜索注册表..."
    
    $results = @()
    
    # 搜索范围
    $searchPaths = @("HKLM:", "HKCU:")
    
    foreach ($path in $searchPaths) {
        Write-Log "搜索路径: $path"
        
        try {
            if ($Recurse) {
                $keys = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
            } else {
                $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
            }
            
            foreach ($key in $keys) {
                $found = $false
                
                # 搜索键名
                if ($SearchKey -and $key.Name -like "*$SearchKey*") {
                    $results += @{
                        Type = "Key"
                        Path = $key.Name
                        Value = ""
                        Data = ""
                    }
                    $found = $true
                }
                
                # 搜索值名和数据
                if ($SearchValue -or $SearchData) {
                    $properties = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                    
                    foreach ($property in $properties.PSObject.Properties) {
                        if ($property.Name -notin "PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider") {
                            $matchValue = $false
                            $matchData = $false
                            
                            if ($SearchValue -and $property.Name -like "*$SearchValue*") {
                                $matchValue = $true
                            }
                            
                            if ($SearchData -and $property.Value -and $property.Value.ToString() -like "*$SearchData*") {
                                $matchData = $true
                            }
                            
                            if ($matchValue -or $matchData) {
                                $results += @{
                                    Type = "Value"
                                    Path = $key.Name
                                    Value = $property.Name
                                    Data = $property.Value
                                }
                                $found = $true
                            }
                        }
                    }
                }
                
                if ($found -and $Verbose) {
                    Write-Log "找到匹配项: $($key.Name)"
                }
            }
            
        } catch {
            Write-Log "搜索路径 $path 时出错: $($_.Exception.Message)"
        }
    }
    
    # 输出结果
    if ($results.Count -gt 0) {
        Write-ColorOutput "找到 $($results.Count) 个匹配项:" -Color Green
        
        foreach ($result in $results) {
            Write-ColorOutput "[$($result.Type)] $($result.Path)" -Color Cyan
            
            if ($result.Value) {
                Write-Host "  值: $($result.Value)" -ForegroundColor Gray
            }
            
            if ($result.Data) {
                $dataStr = $result.Data.ToString()
                if ($dataStr.Length -gt 100) {
                    $dataStr = $dataStr.Substring(0, 100) + "..."
                }
                Write-Host "  数据: $dataStr" -ForegroundColor Gray
            }
            
            Write-Host ""
        }
    } else {
        Write-ColorOutput "未找到匹配项" -Color Yellow
    }
    
    return $results
}

function Clean-Registry {
    Write-Log "开始清理注册表..."
    
    # 确认清理
    if (-not $Force) {
        $title = "确认注册表清理"
        $message = "确定要清理注册表吗？`n`n此操作将删除无效的软件卸载项、临时文件关联等。`n建议在清理前先备份注册表。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "清理注册表"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    $cleanedCount = 0
    
    try {
        # 清理无效的软件卸载项
        Write-Log "清理无效的软件卸载项..."
        
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        
        foreach ($uninstallPath in $uninstallPaths) {
            if (Test-Path $uninstallPath) {
                $items = Get-ChildItem -Path $uninstallPath
                
                foreach ($item in $items) {
                    $properties = Get-ItemProperty -Path $item.PSPath -ErrorAction SilentlyContinue
                    
                    if ($properties) {
                        $displayName = $properties.DisplayName
                        $installLocation = $properties.InstallLocation
                        
                        # 检查安装位置是否存在
                        if ($installLocation -and -not (Test-Path $installLocation)) {
                            if ($Verbose) {
                                Write-Log "删除无效卸载项: $($item.Name) - $displayName"
                            }
                            
                            if (-not $WhatIf) {
                                Remove-Item -Path $item.PSPath -Recurse -Force
                            }
                            
                            $cleanedCount++
                        }
                    }
                }
            }
        }
        
        # 清理文件关联
        Write-Log "清理无效的文件关联..."
        
        $fileAssociationPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"
        
        if (Test-Path $fileAssociationPath) {
            $extensions = Get-ChildItem -Path $fileAssociationPath
            
            foreach ($ext in $extensions) {
                $openWithList = Join-Path $ext.PSPath "OpenWithList"
                
                if (Test-Path $openWithList) {
                    $programs = Get-ChildItem -Path $openWithList
                    
                    foreach ($program in $programs) {
                        $programPath = $program.GetValue("")
                        
                        # 检查程序是否存在
                        if ($programPath -and -not (Test-Path $programPath)) {
                            if ($Verbose) {
                                Write-Log "删除无效文件关联: $($ext.Name) - $programPath"
                            }
                            
                            if (-not $WhatIf) {
                                Remove-Item -Path $program.PSPath -Force
                            }
                            
                            $cleanedCount++
                        }
                    }
                }
            }
        }
        
        # 清理临时注册表项
        Write-Log "清理临时注册表项..."
        
        $tempKeys = @(
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
        )
        
        foreach ($tempKey in $tempKeys) {
            if (Test-Path $tempKey) {
                $items = Get-ChildItem -Path $tempKey
                
                foreach ($item in $items) {
                    if ($Verbose) {
                        Write-Log "删除临时项: $($item.Name)"
                    }
                    
                    if (-not $WhatIf) {
                        Remove-Item -Path $item.PSPath -Recurse -Force
                    }
                    
                    $cleanedCount++
                }
            }
        }
        
        Write-ColorOutput "注册表清理完成，清理了 $cleanedCount 个项目" -Color Green
        Write-Log "注册表清理完成，清理了 $cleanedCount 个项目"
        
    } catch {
        Write-ColorOutput "清理失败: $($_.Exception.Message)" -Color Red
        Write-Log "清理失败: $($_.Exception.Message)"
        throw
    }
}

function Export-RegistryKey {
    param(
        [string]$KeyPath,
        [string]$ExportPath
    )
    
    Write-Log "导出注册表项: $KeyPath"
    
    if (-not (Test-Path $KeyPath)) {
        Write-ColorOutput "注册表项不存在: $KeyPath" -Color Red
        throw "注册表项不存在: $KeyPath"
    }
    
    try {
        if (-not $WhatIf) {
            Start-Process -FilePath "reg" -ArgumentList "export", $KeyPath, $ExportPath, "/y" -Wait -WindowStyle Hidden
        }
        
        Write-ColorOutput "注册表项导出完成: $ExportPath" -Color Green
        Write-Log "注册表项导出完成: $ExportPath"
        
    } catch {
        Write-ColorOutput "导出失败: $($_.Exception.Message)" -Color Red
        Write-Log "导出失败: $($_.Exception.Message)"
        throw
    }
}

function Import-RegistryFile {
    param([string]$ImportPath)
    
    Write-Log "导入注册表文件: $ImportPath"
    
    if (-not (Test-Path $ImportPath)) {
        Write-ColorOutput "注册表文件不存在: $ImportPath" -Color Red
        throw "注册表文件不存在: $ImportPath"
    }
    
    # 确认导入
    if (-not $Force) {
        $title = "确认注册表导入"
        $message = "确定要导入以下注册表文件吗？`n`n$ImportPath`n`n警告：此操作将修改注册表，请确保文件来源可靠。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "导入注册表"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    try {
        if (-not $WhatIf) {
            Start-Process -FilePath "reg" -ArgumentList "import", $ImportPath -Wait -Verb RunAs
        }
        
        Write-ColorOutput "注册表文件导入完成: $ImportPath" -Color Green
        Write-Log "注册表文件导入完成: $ImportPath"
        
    } catch {
        Write-ColorOutput "导入失败: $($_.Exception.Message)" -Color Red
        Write-Log "导入失败: $($_.Exception.Message)"
        throw
    }
}

function Optimize-Registry {
    Write-Log "开始优化注册表..."
    
    # 确认优化
    if (-not $Force) {
        $title = "确认注册表优化"
        $message = "确定要优化注册表吗？`n`n此操作将压缩注册表文件，删除空白空间。`n建议在优化前先备份注册表。"
        $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "优化注册表"
        $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "取消操作"
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
        $result = $host.ui.PromptForChoice($title, $message, $options, 1)
        
        if ($result -ne 0) {
            Write-ColorOutput "操作已取消" -Color Yellow
            return
        }
    }
    
    try {
        # 创建备份
        if (-not $WhatIf) {
            Backup-Registry -BackupPath $BackupPath
        }
        
        # 压缩注册表
        Write-Log "压缩注册表文件..."
        
        if (-not $WhatIf) {
            # 使用reg.exe压缩注册表
            Start-Process -FilePath "reg" -ArgumentList "compress", "HKLM\SOFTWARE" -Wait -WindowStyle Hidden
            Start-Process -FilePath "reg" -ArgumentList "compress", "HKLM\SYSTEM" -Wait -WindowStyle Hidden
            Start-Process -FilePath "reg" -ArgumentList "compress", "HKCU\SOFTWARE" -Wait -WindowStyle Hidden
        }
        
        Write-ColorOutput "注册表优化完成" -Color Green
        Write-Log "注册表优化完成"
        
    } catch {
        Write-ColorOutput "优化失败: $($_.Exception.Message)" -Color Red
        Write-Log "优化失败: $($_.Exception.Message)"
        throw
    }
}

# 主程序
try {
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "      Windows注册表管理工具" -Color Cyan
    Write-ColorOutput "======================================" -Color Cyan
    
    Write-Log "开始注册表管理..."
    Write-Log "命令: $Command"
    
    # 检查管理员权限
    if (-not (Test-AdminPrivileges)) {
        Write-ColorOutput "警告: 某些操作需要管理员权限" -Color Yellow
    }
    
    # 执行命令
    switch ($Command) {
        "backup" {
            Backup-Registry -BackupPath $BackupPath
        }
        
        "restore" {
            if (-not $Path) {
                Write-ColorOutput "错误: 恢复命令需要指定备份文件路径" -Color Red
                exit 1
            }
            Restore-Registry -BackupFile $Path
        }
        
        "clean" {
            Clean-Registry
        }
        
        "search" {
            if (-not $SearchKey -and -not $SearchValue -and -not $SearchData) {
                Write-ColorOutput "错误: 搜索命令需要指定搜索条件" -Color Red
                exit 1
            }
            Search-Registry -SearchKey $SearchKey -SearchValue $SearchValue -SearchData $SearchData -Recurse $Recurse
        }
        
        "export" {
            if (-not $Path) {
                Write-ColorOutput "错误: 导出命令需要指定注册表路径" -Color Red
                exit 1
            }
            
            $exportFile = if ($SearchKey) { $SearchKey } else { "RegistryExport_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg" }
            $exportPath = Join-Path $BackupPath $exportFile
            
            Export-RegistryKey -KeyPath $Path -ExportPath $exportPath
        }
        
        "import" {
            if (-not $Path) {
                Write-ColorOutput "错误: 导入命令需要指定注册表文件路径" -Color Red
                exit 1
            }
            Import-RegistryFile -ImportPath $Path
        }
        
        "optimize" {
            Optimize-Registry
        }
    }
    
    Write-ColorOutput "======================================" -Color Cyan
    Write-ColorOutput "注册表管理完成!" -Color Green
    Write-ColorOutput "日志文件: $LogFile" -Color Green
    
} catch {
    Write-ColorOutput "错误: $($_.Exception.Message)" -Color Red
    Write-Log "错误: $($_.Exception.Message)"
    exit 1
}