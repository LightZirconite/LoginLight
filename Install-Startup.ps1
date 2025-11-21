# Install-Startup.ps1
# Version V2 - Task Scheduler Edition (High Priority)

# --- 1. Vérification des droits Admin (Obligatoire pour le Task Scheduler) ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠️ ATTENTION : Ce script doit être lancé en tant qu'ADMINISTRATEUR pour configurer la priorité haute." -ForegroundColor Red
    Write-Host "Clic droit sur le fichier > 'Exécuter avec PowerShell'" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit
}

$appName = "LoginLight"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$scriptPath = Join-Path $installDir "LoginSplash.ps1"
$assetsDir = Join-Path $installDir "assets"
$videoPath = Join-Path $assetsDir "login.mp4"

# URL Github (A modifier si tu changes de repo)
$githubBaseUrl = "https://raw.githubusercontent.com/LightZirconite/LoginLight/refs/heads/main"
$scriptUrl = "$githubBaseUrl/LoginSplash.ps1" 
$videoUrl = "$githubBaseUrl/assets/login.mp4"

Write-Host "=== LoginLight Ultimate Installer ===" -ForegroundColor Cyan
Write-Host "Mode: Haute Priorité (Task Scheduler)" -ForegroundColor Gray
Write-Host ""

# --- 2. Nettoyage de l'ancienne version (Suppression du raccourci "lent") ---
$startupFolder = [Environment]::GetFolderPath('Startup')
$oldShortcut = Join-Path $startupFolder "$appName.lnk"
if (Test-Path $oldShortcut) {
    Write-Host "Suppression de l'ancien raccourci de démarrage (trop lent)..." -ForegroundColor Yellow
    Remove-Item $oldShortcut -Force
}

# --- 3. Création des dossiers ---
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

# --- 4. Téléchargement des fichiers ---
Write-Host "Téléchargement du script optimisé..." -ForegroundColor Yellow
try {
    # On suppose que tu vas mettre à jour le script sur ton Github avec la version V2 ci-dessous
    # Sinon, pour tester, copie manuellement le fichier après.
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "OK." -ForegroundColor Green
}
catch {
    Write-Host "Erreur téléchargement script. Assurez-vous que l'URL est bonne." -ForegroundColor Red
}

if (-not (Test-Path $videoPath)) {
    Write-Host "Téléchargement de la vidéo..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $videoUrl -OutFile $videoPath -UseBasicParsing -ErrorAction Stop
        Write-Host "OK." -ForegroundColor Green
    }
    catch {
        Write-Host "Erreur téléchargement vidéo." -ForegroundColor Red
    }
} else {
    Write-Host "La vidéo existe déjà, on la garde." -ForegroundColor Gray
}

# --- 5. Configuration du Planificateur de Tâches (Le secret de la vitesse) ---
Write-Host ""
Write-Host "Configuration de la tâche système prioritaire..." -ForegroundColor Yellow

$taskName = "LoginLightSystem"
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Action : Lancer PowerShell sans profil (plus rapide) et caché
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# Trigger : Au moment où l'utilisateur se log
$trigger = New-ScheduledTaskTrigger -AtLogOn

# Settings : Priorité Temps Réel, ne s'arrête pas si sur batterie
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -Priority 0

try {
    # Désinscrire l'ancienne tâche si elle existe
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Créer la nouvelle tâche avec privilèges élevés (Highest)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User $user -RunLevel Highest -Force
    
    Write-Host ""
    Write-Host "✅ SUCCÈS : LoginLight est installé en mode 'God Mode'." -ForegroundColor Green
    Write-Host "Il se lancera AVANT les autres applications au prochain démarrage." -ForegroundColor Cyan
}
catch {
    Write-Host "❌ ERREUR lors de la création de la tâche : $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Appuyez sur une touche pour quitter..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")