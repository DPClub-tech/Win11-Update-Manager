# Copyright (c) 2026 DPClub-tech
# Licensed under the MIT License.
# ================================================
#   WINDOWS 11 UPDATE MANAGER
#   Version: 4.0
#   Features: Enable / Fast Enable / Disable / Open UI / Self-Update
# ================================================

# Auto-elevation to Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Requesting Administrator rights..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

$Host.UI.RawUI.WindowTitle = "Windows 11 Update Manager v4.0"
chcp 65001 > $null
Clear-Host

# ================================================
# FUNCTION 1: FULL ENABLE + REPAIR
# ================================================
function Enable-FullRepair {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "      ENABLING WINDOWS UPDATE + SYSTEM CHECK" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan
    
    Write-Host "`n[Step 1/4] Restoring service paths (registry)..." -ForegroundColor Gray
    $servicesPath = "HKLM:\SYSTEM\CurrentControlSet\Services"
    Set-ItemProperty -Path "$servicesPath\WaaSMedicSvc" -Name "ImagePath" -Value "%systemroot%\system32\svchost.exe -k wusvcs -p" -Type ExpandString -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "$servicesPath\wuauserv" -Name "ImagePath" -Value "%systemroot%\system32\svchost.exe -k netsvcs -p" -Type ExpandString -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "$servicesPath\UsoSvc" -Name "ImagePath" -Value "%systemroot%\system32\svchost.exe -k netsvcs -p" -Type ExpandString -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "$servicesPath\DoSvc" -Name "ImagePath" -Value "%SystemRoot%\System32\svchost.exe -k NetworkService -p" -Type ExpandString -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "$servicesPath\mpsdrv" -Name "ImagePath" -Value "System32\drivers\mpsdrv.sys" -Type ExpandString -Force -ErrorAction SilentlyContinue

    Write-Host "[Step 2/4] Removing blocking policies (registry)..." -ForegroundColor Gray
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    if (Test-Path $policyPath) {
        Remove-Item -Path $policyPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    $uxPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    if (-not (Test-Path $uxPath)) { New-Item -Path $uxPath -Force | Out-Null }
    Set-ItemProperty -Path $uxPath -Name "AllowAutoWindowsUpdateDownloadOverMeteredNetwork" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $uxPath -Name "PausedFeatureStatus" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $uxPath -Name "PausedQualityStatus" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $uxPath -Name "PauseFeatureUpdatesEndTime" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $uxPath -Name "PauseQualityUpdatesEndTime" -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $uxPath -Name "PauseUpdatesExpiryTime" -Force -ErrorAction SilentlyContinue

    Write-Host "[Step 3/4] Starting services..." -ForegroundColor Gray
    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name bits -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name cryptsvc -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name TrustedInstaller -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name UsoSvc -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name WaaSMedicSvc -StartupType Manual -ErrorAction SilentlyContinue
    
    Start-Service -Name wuauserv, bits, cryptsvc, TrustedInstaller, UsoSvc -ErrorAction SilentlyContinue

    Write-Host "[Step 4/4] System check (DISM ScanHealth + SFC)..." -ForegroundColor Gray
    Write-Host "    Checking component store health (fast)..." -ForegroundColor DarkYellow
    DISM /Online /Cleanup-Image /ScanHealth /Quiet
    Write-Host "    Running SFC Scannow..." -ForegroundColor DarkYellow
    sfc /scannow | Out-Null
    Write-Host "    (If errors reported, run DISM /RestoreHealth manually later.)" -ForegroundColor DarkGray

    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "  DONE! Updates ENABLED + System checked." -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Green
}

# ================================================
# FUNCTION 2: FAST ENABLE (REGISTRY + SERVICE START)
# ================================================
function Enable-FastRegistry {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "         FAST ENABLE (REGISTRY + SERVICES)" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Cyan

    Write-Host "`n[Action 1/2] Applying registry fixes (exact BAT commands)..." -ForegroundColor Gray

    $regCommands = @(
        'REG ADD "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings" /v PausedFeatureStatus /t REG_DWORD /d 0 /f',
        'REG ADD "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings" /v PausedQualityStatus /t REG_DWORD /d 0 /f',
        'REG ADD "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v AllowAutoWindowsUpdateDownloadOverMeteredNetwork /t REG_DWORD /d 0 /f',
        'REG DELETE "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesEndTime /f',
        'REG DELETE "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseFeatureUpdatesStartTime /f',
        'REG DELETE "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseQualityUpdatesEndTime /f',
        'REG DELETE "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseQualityUpdatesStartTime /f',
        'REG DELETE "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v PauseUpdatesExpiryTime /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f',
        'REG ADD "HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 1 /f',
        'REG ADD "HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DownloadMode_BackCompat /t REG_DWORD /d 1 /f',
        'REG DELETE "HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" /v DownloadMode /f',
        'REG DELETE "HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" /v DownloadModeProvider /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DeferFeatureUpdates /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableDualScan /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableOSUpgrade /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DoNotConnectToWindowsUpdateInternetLocations /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v UpdateNotificationLevel /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v UpdateServiceUrlAlternate /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DoNotAllowDeferUpgrade /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AlwaysAutoRebootAtScheduledTime /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v EnableFeaturedSoftware /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v IncludeRecommendedUpdates /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f',
        'REG DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v ImagePath /t REG_EXPAND_SZ /d "%systemroot%\system32\svchost.exe -k wusvcs -p" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\wuauserv" /v ImagePath /t REG_EXPAND_SZ /d "%systemroot%\system32\svchost.exe -k netsvcs -p" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\mpsdrv" /v ImagePath /t REG_EXPAND_SZ /d "System32\drivers\mpsdrv.sys" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\DoSvc" /v ImagePath /t REG_EXPAND_SZ /d "%%SystemRoot%%\System32\svchost.exe -k NetworkService -p" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\UsoSvc" /v ImagePath /t REG_EXPAND_SZ /d "%systemroot%\system32\svchost.exe -k netsvcs -p" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Sense" /v ImagePath /t REG_EXPAND_SZ /d "%%ProgramFiles%%\Windows Defender Advanced Threat Protection\MsSense.exe" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\WdNisSvc" /v ImagePath /t REG_EXPAND_SZ /d "%%ProgramFiles%%\Windows Defender\NisSrv.exe" /f',
        'REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\wscsvc" /v ImagePath /t REG_EXPAND_SZ /d "%%SystemRoot%%\System32\svchost.exe -k LocalServiceNetworkRestricted -p" /f'
    )

    $count = 1
    $total = $regCommands.Count
    
    foreach ($cmd in $regCommands) {
        Write-Progress -Activity "Applying registry fixes" -Status "Command $count of $total" -PercentComplete (($count / $total) * 100)
        cmd.exe /c $cmd 2>&1 | Out-Null
        $count++
    }
    
    Write-Progress -Activity "Applying registry fixes" -Completed

    Write-Host "`n[Action 2/2] Starting Windows Update services..." -ForegroundColor Gray
    
    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name bits -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name cryptsvc -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name TrustedInstaller -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name UsoSvc -StartupType Manual -ErrorAction SilentlyContinue
    Set-Service -Name WaaSMedicSvc -StartupType Manual -ErrorAction SilentlyContinue
    
    Start-Service -Name wuauserv, bits, cryptsvc, TrustedInstaller, UsoSvc -ErrorAction SilentlyContinue
    
    $wuauservStatus = (Get-Service -Name wuauserv -ErrorAction SilentlyContinue).Status
    if ($wuauservStatus -eq 'Running') {
        Write-Host "    Windows Update service: RUNNING" -ForegroundColor Green
    } else {
        Write-Host "    Windows Update service: NOT RUNNING (Status: $wuauservStatus)" -ForegroundColor Red
        Write-Host "    Try running Option 1 (Full Repair) for deeper recovery." -ForegroundColor DarkYellow
    }

    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "  DONE! Registry fixed + Services started." -ForegroundColor White
    Write-Host "  $total registry commands executed." -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Green
}

# ================================================
# FUNCTION 3: DISABLE UPDATES
# ================================================
function Disable-WindowsUpdate {
    Write-Host "`n================================================" -ForegroundColor Red
    Write-Host "         DISABLING WINDOWS UPDATE" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Red

    Write-Host "`n[Step 1/3] Setting block policies..." -ForegroundColor Gray
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
    
    Set-ItemProperty -Path $policyPath -Name "NoAutoUpdate" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $policyPath -Name "AUOptions" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $policyPath -Name "UseWUServer" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $policyPath -Name "WUServer" -Value " " -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "WUStatusServer" -Value " " -Type String -Force
    Set-ItemProperty -Path $policyPath -Name "DisableOSUpgrade" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $policyPath -Name "DisableWindowsUpdateAccess" -Value 1 -Type DWord -Force

    Write-Host "[Step 2/3] Stopping and disabling services..." -ForegroundColor Gray
    Stop-Service -Name wuauserv, bits, UsoSvc, WaaSMedicSvc, DoSvc -Force -ErrorAction SilentlyContinue
    Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name bits -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name UsoSvc -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name WaaSMedicSvc -StartupType Disabled -ErrorAction SilentlyContinue
    Set-Service -Name DoSvc -StartupType Disabled -ErrorAction SilentlyContinue

    Write-Host "[Step 3/3] Clearing update cache..." -ForegroundColor Gray
    Remove-Item -Path "$env:windir\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "  DONE! Windows Update is DISABLED." -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Green
}

# ================================================
# FUNCTION 4: OPEN WINDOWS UPDATE
# ================================================
function Start-UpdateCheckUI {
    Write-Host "`n================================================" -ForegroundColor Magenta
    Write-Host "         OPENING WINDOWS UPDATE" -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Magenta

    Write-Host "`n[Action] Opening Windows Update settings..." -ForegroundColor Gray
    Start-Process "ms-settings:windowsupdate" 

    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "  Windows Update opened successfully." -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Green
}

# ================================================
# FUNCTION 5: CHECK FOR SCRIPT UPDATES
# ================================================
function Update-Script {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "         CHECKING FOR SCRIPT UPDATES" -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Cyan

    $UpdateUrl = "https://raw.githubusercontent.com/DPClub-tech/Win11-Update-Manager/main/Win11_Update_Manager.ps1"
    $CurrentVersion = "4.0"
    
    Write-Host "`n[Action 1] Current version: $CurrentVersion" -ForegroundColor Gray
    Write-Host "[Action 2] Checking for updates online..." -ForegroundColor Gray
    
    try {
        $webClient = New-Object System.Net.WebClient
        $RemoteContent = $webClient.DownloadString($UpdateUrl)
        
        if ($RemoteContent -match 'Version:\s*([\d\.]+)') {
            $RemoteVersion = $matches[1]
            Write-Host "[Action 3] Remote version: $RemoteVersion" -ForegroundColor Gray
            
            if ([version]$RemoteVersion -gt [version]$CurrentVersion) {
                Write-Host "`n    New version available! v$RemoteVersion" -ForegroundColor Yellow
                $confirm = Read-Host "    Download and install update? (Y/N)"
                
                if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                    Write-Host "`n[Action 4] Downloading new version..." -ForegroundColor Gray
                    
                    $BackupPath = "$PSCommandPath.old"
                    Copy-Item -Path $PSCommandPath -Destination $BackupPath -Force
                    
                    $RemoteContent | Out-File -FilePath $PSCommandPath -Encoding UTF8 -Force
                    
                    Write-Host "`n================================================" -ForegroundColor Green
                    Write-Host "  Script updated to v$RemoteVersion!" -ForegroundColor White
                    Write-Host "  Backup saved as: $BackupPath" -ForegroundColor DarkGray
                    Write-Host "  Restart script to apply changes." -ForegroundColor Yellow
                    Write-Host "================================================" -ForegroundColor Green
                } else {
                    Write-Host "`n    Update cancelled." -ForegroundColor DarkGray
                }
            } else {
                Write-Host "`n    You are running the latest version." -ForegroundColor Green
            }
        } else {
            Write-Host "`n    Could not determine remote version." -ForegroundColor Red
        }
    } catch {
        Write-Host "`n    Failed to check for updates. Check your internet connection." -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
    
    Write-Host "`n================================================" -ForegroundColor Green
}

# ================================================
# MAIN MENU
# ================================================
$running = $true

do {
    Clear-Host
    Write-Host "`n"
    Write-Host "  ==============================================" -ForegroundColor Cyan
    Write-Host "        WINDOWS 11 UPDATE MANAGER v4.0" -ForegroundColor White
    Write-Host "  ==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1]  ENABLE + REPAIR (Full)" -ForegroundColor Green
    Write-Host "        (Registry + Start services + System check)"
    Write-Host ""
    Write-Host "   [2]  ENABLE (FAST - Registry + Services)" -ForegroundColor Green
    Write-Host "        (Registry fix + Service start - NO system check)"
    Write-Host ""
    Write-Host "   [3]  DISABLE Windows Update" -ForegroundColor Red
    Write-Host "        (Block via policies, stop services)"
    Write-Host ""
    Write-Host "   [4]  OPEN Windows Update" -ForegroundColor Yellow
    Write-Host "        (Open Settings -> Windows Update)"
    Write-Host ""
    Write-Host "   [5]  CHECK for script updates" -ForegroundColor Magenta
    Write-Host "        (Download latest version if available)"
    Write-Host ""
    Write-Host "   [0]  EXIT" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ==============================================" -ForegroundColor Cyan
    Write-Host "  GitHub: DPClub-tech/Win11-Update-Manager" -ForegroundColor DarkGray
    Write-Host ""
    
    $choice = Read-Host "Your choice"
    
    switch ($choice) {
        '1' { Enable-FullRepair }
        '2' { Enable-FastRegistry }
        '3' { Disable-WindowsUpdate }
        '4' { Start-UpdateCheckUI }
        '5' { Update-Script }
        '0' { 
            Write-Host "`nExiting Windows 11 Update Manager..." -ForegroundColor Gray
            Start-Sleep -Seconds 1
            $running = $false
            break
        }
        default { 
            Write-Host "`n   [!] Invalid input. Press 1, 2, 3, 4, 5 or 0." -ForegroundColor Red
        }
    }
    
    if ($running -and $choice -match '^[12345]$') {
        Write-Host "`n"
        Write-Host "Press any key to return to menu..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
} while ($running)

Write-Host "Goodbye!" -ForegroundColor Cyan
Start-Sleep -Seconds 1
Exit