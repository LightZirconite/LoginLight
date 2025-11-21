# Uninstall-Startup.ps1
# Removes LoginLight from Windows startup

$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$appName = "LoginLight"
$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder "$appName.lnk"

Write-Host "=== LoginLight Startup Uninstaller ===" -ForegroundColor Cyan
Write-Host ""

$removed = $false

try {
  $existing = Get-ItemProperty -Path $registryPath -Name $appName -ErrorAction SilentlyContinue
  
  if ($existing) {
    Remove-ItemProperty -Path $registryPath -Name $appName -ErrorAction Stop
    Write-Host "Removed from Registry Run key" -ForegroundColor Green
    $removed = $true
  }
  
  if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force -ErrorAction Stop
    Write-Host "Removed from Startup folder" -ForegroundColor Green
    $removed = $true
  }
  
  if ($removed) {
    Write-Host ""
    Write-Host "SUCCESS: LoginLight removed from Windows startup!" -ForegroundColor Green
  } else {
    Write-Host "INFO: LoginLight was not found in startup entries." -ForegroundColor Yellow
  }
}
catch {
  Write-Host "ERROR: Failed to remove startup entry." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  pause
  exit 1
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
