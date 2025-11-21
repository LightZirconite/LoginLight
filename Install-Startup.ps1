# Install-Startup.ps1
# Downloads and installs LoginLight to start automatically at Windows login

$appName = "LoginLight"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$scriptPath = Join-Path $installDir "LoginSplash.ps1"
$assetsDir = Join-Path $installDir "assets"
$videoPath = Join-Path $assetsDir "login.mp4"
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

$githubBaseUrl = "https://raw.githubusercontent.com/LightZirconite/LoginLight/refs/heads/main"
$scriptUrl = "$githubBaseUrl/LoginSplash.ps1"
$videoUrl = "$githubBaseUrl/assets/login.mp4"

Write-Host "=== LoginLight Startup Installer ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation directory: $installDir" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $installDir)) {
  Write-Host "Creating installation directory..." -ForegroundColor Yellow
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

if (-not (Test-Path $assetsDir)) {
  New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

Write-Host "Downloading LoginSplash.ps1..." -ForegroundColor Yellow
try {
  Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
  Write-Host "  Downloaded LoginSplash.ps1" -ForegroundColor Green
}
catch {
  Write-Host "ERROR: Failed to download LoginSplash.ps1" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  pause
  exit 1
}

Write-Host "Downloading video (login.mp4)..." -ForegroundColor Yellow
try {
  Invoke-WebRequest -Uri $videoUrl -OutFile $videoPath -UseBasicParsing -ErrorAction Stop
  Write-Host "  Downloaded login.mp4" -ForegroundColor Green
}
catch {
  Write-Host "ERROR: Failed to download video file" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  pause
  exit 1
}

Write-Host ""
Write-Host "Registering to Windows startup..." -ForegroundColor Yellow

try {
  $startupFolder = [Environment]::GetFolderPath('Startup')
  $shortcutPath = Join-Path $startupFolder "$appName.lnk"
  
  $WshShell = New-Object -ComObject WScript.Shell
  $shortcut = $WshShell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = "powershell.exe"
  $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
  $shortcut.WorkingDirectory = $installDir
  $shortcut.WindowStyle = 7
  $shortcut.Save()
  
  Write-Host ""
  Write-Host "SUCCESS: LoginLight installed!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Installation details:" -ForegroundColor Yellow
  Write-Host "  - Location: $installDir" -ForegroundColor Gray
  Write-Host "  - Startup shortcut: $shortcutPath" -ForegroundColor Gray
  Write-Host ""
  Write-Host "The splash screen will appear automatically on next login." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "To uninstall, run the Uninstall-Startup.ps1 script." -ForegroundColor Gray
}
catch {
  Write-Host ""
  Write-Host "ERROR: Failed to register startup entry." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  pause
  exit 1
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
