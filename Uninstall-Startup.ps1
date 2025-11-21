# Uninstall-Startup.ps1
# Completely removes LoginLight (Files + Scheduled Task + Shortcuts)
# Language: English | Mode: Admin Auto-Elevation

# --- 0. ADMIN SELF-ELEVATION ---
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Admin rights are required to remove the system task..." -ForegroundColor Yellow
    Write-Host "Restarting script as Administrator..." -ForegroundColor Cyan
    
    # Relaunch self with "RunAs" (triggers UAC prompt)
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    
    exit
}

# --- START UNINSTALLATION (Admin Mode) ---

$appName = "LoginLight"
$taskName = "LoginLightSystem"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$startupFolder = [Environment]::GetFolderPath('Startup')
$legacyShortcut = Join-Path $startupFolder "$appName.lnk"

Clear-Host
Write-Host "=== LoginLight Uninstaller ===" -ForegroundColor Cyan
Write-Host ""

$cleanupCount = 0

# --- 1. REMOVE SCHEDULED TASK ---
Write-Host "Checking for Scheduled Task..." -ForegroundColor Yellow
try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "  [REMOVED] System Task '$taskName'" -ForegroundColor Green
        $cleanupCount++
    } else {
        Write-Host "  [INFO] No Scheduled Task found." -ForegroundColor Gray
    }
}
catch {
    Write-Host "  [ERROR] Failed to remove Scheduled Task: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 2. REMOVE LEGACY SHORTCUT ---
if (Test-Path $legacyShortcut) {
    try {
        Remove-Item $legacyShortcut -Force -ErrorAction Stop
        Write-Host "  [REMOVED] Legacy Startup Shortcut" -ForegroundColor Green
        $cleanupCount++
    }
    catch {
        Write-Host "  [ERROR] Could not remove shortcut." -ForegroundColor Red
    }
}

# --- 3. REMOVE INSTALLATION FILES ---
if (Test-Path $installDir) {
    try {
        # Stop any running instances first
        Get-Process -Name "powershell" | Where-Object { $_.MainWindowTitle -eq "" } | Stop-Process -ErrorAction SilentlyContinue
        
        Remove-Item $installDir -Recurse -Force -ErrorAction Stop
        Write-Host "  [DELETED] Installation Directory ($installDir)" -ForegroundColor Green
        $cleanupCount++
    }
    catch {
        Write-Host "  [ERROR] Failed to delete files. Verify no files are open." -ForegroundColor Red
        Write-Host "  Details: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [INFO] Installation directory not found." -ForegroundColor Gray
}

# --- SUMMARY ---
Write-Host ""
if ($cleanupCount -gt 0) {
    Write-Host "SUCCESS: LoginLight has been completely uninstalled." -ForegroundColor Green
} else {
    Write-Host "Clean uninstallation complete (Nothing was found to remove)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")