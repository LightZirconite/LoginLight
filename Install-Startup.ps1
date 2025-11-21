# Install-Startup.ps1
# Installs LoginLight with High Priority via Windows Task Scheduler
# Language: English | Mode: Admin Auto-Elevation

# --- 0. ADMIN SELF-ELEVATION ---
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Admin rights are required to configure high-priority startup..." -ForegroundColor Yellow
    Write-Host "Restarting script as Administrator..." -ForegroundColor Cyan
    
    # Relaunch self with "RunAs" (triggers UAC prompt)
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    
    exit
}

# --- START INSTALLATION (Admin Mode) ---

$appName = "LoginLight"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$scriptPath = Join-Path $installDir "LoginSplash.ps1"
$assetsDir = Join-Path $installDir "assets"
$videoPath = Join-Path $assetsDir "login.mp4"

# --- GITHUB CONFIGURATION ---
# Ensure these URLs point to the RAW versions of your files
$githubBaseUrl = "https://raw.githubusercontent.com/LightZirconite/LoginLight/refs/heads/main"
$scriptUrl = "$githubBaseUrl/LoginSplash.ps1"
$videoUrl = "$githubBaseUrl/assets/login.mp4"

Clear-Host
Write-Host "=== LoginLight Ultimate Installer ===" -ForegroundColor Cyan
Write-Host "Mode: Administrator (High Priority System Task)" -ForegroundColor Green
Write-Host ""

# --- 1. CLEANUP LEGACY SHORTCUTS ---
# We remove the old 'shell:startup' shortcut because it is too slow.
$startupFolder = [Environment]::GetFolderPath('Startup')
$oldShortcut = Join-Path $startupFolder "$appName.lnk"
if (Test-Path $oldShortcut) {
    Write-Host "Removing legacy startup shortcut (too slow)..." -ForegroundColor Yellow
    Remove-Item $oldShortcut -Force
}

# --- 2. CREATE DIRECTORIES ---
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "Created directory: $installDir" -ForegroundColor Gray
}
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

# --- 3. DOWNLOAD FILES ---
Write-Host "Downloading LoginSplash.ps1..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "  Success." -ForegroundColor Green
}
catch {
    Write-Host "  ERROR: Failed to download script." -ForegroundColor Red
    Write-Host "  Details: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

if (-not (Test-Path $videoPath)) {
    Write-Host "Downloading video (login.mp4)..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $videoUrl -OutFile $videoPath -UseBasicParsing -ErrorAction Stop
        Write-Host "  Success." -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR: Failed to download video." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }
} else {
    Write-Host "Video file already exists. Skipping download." -ForegroundColor Gray
}

# --- 4. CONFIGURE TASK SCHEDULER ---
Write-Host ""
Write-Host "Configuring High-Priority System Task..." -ForegroundColor Yellow

$taskName = "LoginLightSystem"
$targetUser = $env:USERNAME 

try {
    # Action: Run PowerShell hidden, no profile, bypassing execution policy
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Trigger: At user LogOn
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Settings: Priority 0 (RealTime), Allow on Battery, No network requirement
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -Priority 0
    
    # Principal: Run as the specific user with HIGHEST privileges (Admin)
    $principal = New-ScheduledTaskPrincipal -UserId $targetUser -LogonType Interactive -RunLevel Highest

    # Remove old task if exists
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Register the new task
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
    
    Write-Host "SUCCESS: Task created!" -ForegroundColor Green
    Write-Host ""
    Write-Host "LoginLight is now installed for user: $targetUser" -ForegroundColor Cyan
    Write-Host "It will launch BEFORE other applications on next login." -ForegroundColor Cyan
}
catch {
    Write-Host "CRITICAL ERROR while creating task." -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")