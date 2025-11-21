# Uninstall-Startup.ps1
# Removes LoginLight from Windows startup and deletes installation files

$appName = "LoginLight"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$startupFolder = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder "$appName.lnk"

Write-Host "=== LoginLight Startup Uninstaller ===" -ForegroundColor Cyan
Write-Host ""

$removed = $false

try {
  if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force -ErrorAction Stop
    Write-Host "Removed startup shortcut" -ForegroundColor Green
    $removed = $true
  }
  
  if (Test-Path $installDir) {
    Remove-Item $installDir -Recurse -Force -ErrorAction Stop
    Write-Host "Deleted installation files: $installDir" -ForegroundColor Green
    $removed = $true
  }
  
  if ($removed) {
    Write-Host ""
    Write-Host "SUCCESS: LoginLight completely uninstalled!" -ForegroundColor Green
  } else {
    Write-Host "INFO: LoginLight was not found." -ForegroundColor Yellow
  }
}
catch {
  Write-Host "ERROR: Failed to uninstall." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  pause
  exit 1
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
