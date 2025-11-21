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

# Liens GitHub (A VERIFIER: Assure-toi que ces liens pointent bien vers tes fichiers bruts/raw)
$githubBaseUrl = "https://raw.githubusercontent.com/LightZirconite/LoginLight/refs/heads/main"
$scriptUrl = "$githubBaseUrl/LoginSplash.ps1"
$videoUrl = "$githubBaseUrl/assets/login.mp4"

Write-Host "=== LoginLight Ultimate Installer ===" -ForegroundColor Cyan
Write-Host "Mode: Administrateur (High Priority System Task)" -ForegroundColor Green
Write-Host ""

# --- 1. Nettoyage ---
# On supprime l'ancien raccourci shell:startup s'il existe (car il est trop lent)
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

# --- 4. Configuration du Planificateur de Tâches (Le Secret) ---
Write-Host ""
Write-Host "Création de la tâche planifiée haute priorité..." -ForegroundColor Yellow

$taskName = "LoginLightSystem"
# On récupère le nom de l'utilisateur actuel pour que la tâche se lance sur SA session
# Note: En mode Admin, [Environment]::UserName peut parfois donner "SYSTEM", donc on reste prudent
# On va configurer la tâche pour s'exécuter pour le groupe "Users" au moment du logon interactif

try {
    # Action : Lancer PowerShell caché sans profil
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    # Déclencheur : À l'ouverture de session de n'importe quel utilisateur
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Paramètres : Priorité Temps Réel (0), permet le démarrage sur batterie
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -Priority 0
    
    # Désinscrire l'ancienne tâche si elle existe pour éviter les doublons
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    # Création de la tâche
    # -RunLevel Highest : C'est ça qui donne les droits Admin au script de démarrage
    # -User : On utilise "NT AUTHORITY\INTERACTIVE" pour cibler l'utilisateur qui se connecte physiquement
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User "BUILTIN\Users" -RunLevel Highest -Force | Out-Null
    
    Write-Host "✅ TÂCHE CRÉÉE AVEC SUCCÈS !" -ForegroundColor Green
    Write-Host ""
    Write-Host "LoginLight est maintenant configuré en mode prioritaire." -ForegroundColor Cyan
    Write-Host "Il démarrera AVANT les applications classiques (Discord, Steam, etc.)" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ ERREUR CRITIQUE lors de la création de la tâche." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")