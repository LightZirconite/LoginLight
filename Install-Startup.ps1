# Install-Startup.ps1
# Registers LoginLight to start automatically at Windows login

$scriptPath = Join-Path $PSScriptRoot "LoginSplash.ps1"
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$shellStartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
$appName = "LoginLight"

Write-Host "=== LoginLight Startup Installer ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $scriptPath)) {
  Write-Host "ERROR: LoginSplash.ps1 not found in current directory." -ForegroundColor Red
  Write-Host "Please run this script from the LoginLight folder." -ForegroundColor Red
  pause
  exit 1
}

$command = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

try {
  Set-ItemProperty -Path $registryPath -Name $appName -Value $command -Type String -ErrorAction Stop
  
  $startupFolder = [Environment]::GetFolderPath('Startup')
  $shortcutPath = Join-Path $startupFolder "$appName.lnk"
  
  $WshShell = New-Object -ComObject WScript.Shell
  $shortcut = $WshShell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = "powershell.exe"
  $shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
  $shortcut.WorkingDirectory = $PSScriptRoot
  $shortcut.WindowStyle = 7
  $shortcut.Save()
  
  Write-Host "SUCCESS: LoginLight installed to Windows startup!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Installed to:" -ForegroundColor Yellow
  Write-Host "  - Registry Run key (standard)" -ForegroundColor Gray
  Write-Host "  - Startup folder (priority): $shortcutPath" -ForegroundColor Gray
  Write-Host ""
  Write-Host "The splash screen will appear automatically on next login." -ForegroundColor Yellow
}
catch {
  Write-Host "ERROR: Failed to register startup entry." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  pause
  exit 1
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
