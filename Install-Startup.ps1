# Install-Startup.ps1
# Installe LoginLight avec priorité MAXIMALE via le Planificateur de Tâches
# Inclut l'auto-élévation en Administrateur

# --- 0. AUTO-ÉLÉVATION EN ADMINISTRATEUR ---
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Besoin des droits Administrateur pour configurer le démarrage rapide..." -ForegroundColor Yellow
    Write-Host "Relancement du script en mode Admin..." -ForegroundColor Cyan
    
    # Relance le même script avec l'argument "RunAs" qui déclenche le prompt UAC
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    
    # On quitte l'instance non-admin
    exit
}

# --- DÉBUT DE L'INSTALLATION (Mode Admin confirmé) ---

$appName = "LoginLight"
$installDir = Join-Path $env:LOCALAPPDATA $appName
$scriptPath = Join-Path $installDir "LoginSplash.ps1"
$assetsDir = Join-Path $installDir "assets"
$videoPath = Join-Path $assetsDir "login.mp4"

# Liens GitHub
$githubBaseUrl = "https://raw.githubusercontent.com/LightZirconite/LoginLight/refs/heads/main"
$scriptUrl = "$githubBaseUrl/LoginSplash.ps1"
$videoUrl = "$githubBaseUrl/assets/login.mp4"

Write-Host "=== LoginLight Ultimate Installer ===" -ForegroundColor Cyan
Write-Host "Mode: Administrateur (High Priority System Task)" -ForegroundColor Green
Write-Host ""

# --- 1. Nettoyage ---
$startupFolder = [Environment]::GetFolderPath('Startup')
$oldShortcut = Join-Path $startupFolder "$appName.lnk"
if (Test-Path $oldShortcut) {
    Write-Host "Suppression de l'ancien raccourci lent..." -ForegroundColor Yellow
    Remove-Item $oldShortcut -Force
}

# --- 2. Création des dossiers ---
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "Dossier créé : $installDir" -ForegroundColor Gray
}
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
}

# --- 3. Téléchargement des fichiers ---
Write-Host "Téléchargement du script LoginSplash.ps1..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing -ErrorAction Stop
    Write-Host "  OK." -ForegroundColor Green
}
catch {
    Write-Host "  ERREUR: Impossible de télécharger le script." -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour quitter"
    exit
}

if (-not (Test-Path $videoPath)) {
    Write-Host "Téléchargement de la vidéo..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $videoUrl -OutFile $videoPath -UseBasicParsing -ErrorAction Stop
        Write-Host "  OK." -ForegroundColor Green
    }
    catch {
        Write-Host "  ERREUR: Impossible de télécharger la vidéo." -ForegroundColor Red
        Read-Host "Appuyez sur Entrée pour quitter"
        exit
    }
} else {
    Write-Host "La vidéo existe déjà, on la conserve." -ForegroundColor Gray
}

# --- 4. Configuration du Planificateur de Tâches (CORRIGÉ) ---
Write-Host ""
Write-Host "Création de la tâche planifiée haute priorité..." -ForegroundColor Yellow

$taskName = "LoginLightSystem"
# CORRECTION ICI : On cible l'utilisateur courant explicitement au lieu du groupe "Users"
# Cela corrige l'erreur XML 0x80041318
$targetUser = $env:USERNAME 

try {
    # Action : Lancer PowerShell caché sans profil
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Déclencheur : À l'ouverture de session
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Paramètres : Priorité Temps Réel (0)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -Priority 0
    
    # Principal : On définit l'utilisateur ET le niveau de privilège ici
    $principal = New-ScheduledTaskPrincipal -UserId $targetUser -LogonType Interactive -RunLevel Highest

    # Désinscrire l'ancienne tâche si elle existe
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Création de la tâche avec l'objet Principal corrigé
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
    
    Write-Host "✅ TÂCHE CRÉÉE AVEC SUCCÈS !" -ForegroundColor Green
    Write-Host ""
    Write-Host "LoginLight est maintenant configuré pour l'utilisateur : $targetUser" -ForegroundColor Cyan
    Write-Host "Il démarrera AVANT les applications classiques." -ForegroundColor Cyan
}
catch {
    Write-Host "❌ ERREUR CRITIQUE lors de la création de la tâche." -ForegroundColor Red
    Write-Host "Code erreur : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Détail : $($_.FullyQualifiedErrorId)" -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")