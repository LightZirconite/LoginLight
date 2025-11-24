# Uninstall-Startup.ps1
# Version: V3 "Path Finder Edition"
# Language: English (Logic), French (Messages)

# --- 0. RECUPERATION ROBUSTE DU CHEMIN ---
# On essaie deux méthodes pour trouver où est ce fichier
$currentScriptPath = $PSCommandPath
if (-not $currentScriptPath) {
    $currentScriptPath = $MyInvocation.MyCommand.Path
}

# Si après ça, le chemin est toujours vide, c'est que le fichier n'est pas sauvegardé ou exécuté bizarrement
if (-not $currentScriptPath) {
    Write-Host "ERREUR CRITIQUE : Le script ne trouve pas son propre chemin." -ForegroundColor Red
    Write-Host "1. Assurez-vous que ce fichier est bien SAUVEGARDÉ sur votre disque." -ForegroundColor Yellow
    Write-Host "2. Faites Clic-Droit sur le fichier > 'Exécuter avec PowerShell'." -ForegroundColor Yellow
    Read-Host "Appuyez sur Entrée pour quitter..."
    exit
}

# --- 1. AUTO-ELEVATION ADMIN ---
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Droits Admin requis. Relance du script..." -ForegroundColor Yellow
    
    # On utilise le chemin qu'on a validé juste au-dessus
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$currentScriptPath`""
        exit
    } catch {
        Write-Host "Impossible de relancer en Admin automatiquement." -ForegroundColor Red
        Write-Host "Veuillez faire Clic-Droit sur le fichier > 'Exécuter en tant qu'administrateur'." -ForegroundColor Red
        Read-Host "Entrée pour quitter..."
        exit
    }
}

# --- 2. BLOC DE DESINSTALLATION ---
try {
    Clear-Host
    Write-Host "=== LoginLight Désinstallateur V3 ===" -ForegroundColor Cyan
    Write-Host "Mode : Administrateur" -ForegroundColor Green
    Write-Host ""

    $appName = "LoginLight"
    $taskName = "LoginLightSystem"
    $installDir = Join-Path $env:LOCALAPPDATA $appName
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $legacyShortcut = Join-Path $startupFolder "$appName.lnk"
    $cleanupCount = 0

    # A. SUPPRESSION TÂCHE PLANIFIÉE
    Write-Host "1. Vérification de la tâche planifiée..." -ForegroundColor Yellow
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Host "   [OK] Tâche système supprimée." -ForegroundColor Green
            $cleanupCount++
        } else {
            Write-Host "   [INFO] Aucune tâche trouvée." -ForegroundColor Gray
        }
    } catch {
        Write-Host "   [ERREUR] Impossible de supprimer la tâche : $($_.Exception.Message)" -ForegroundColor Red
    }

    # B. SUPPRESSION RACCOURCI
    Write-Host "2. Vérification des raccourcis..." -ForegroundColor Yellow
    if (Test-Path $legacyShortcut) {
        try {
            Remove-Item $legacyShortcut -Force -ErrorAction Stop
            Write-Host "   [OK] Raccourci de démarrage supprimé." -ForegroundColor Green
            $cleanupCount++
        } catch { Write-Host "   [ERREUR] Raccourci bloqué." -ForegroundColor Red }
    } else {
        Write-Host "   [INFO] Aucun raccourci trouvé." -ForegroundColor Gray
    }

    # C. SUPPRESSION FICHIERS
    Write-Host "3. Nettoyage des fichiers..." -ForegroundColor Yellow
    if (Test-Path $installDir) {
        # Tuer les processus fantômes
        try {
            $myPid = $PID
            Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $myPid -and $_.MainWindowTitle -eq "" } | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}

        try {
            Remove-Item $installDir -Recurse -Force -ErrorAction Stop
            Write-Host "   [OK] Dossier supprimé ($installDir)." -ForegroundColor Green
            $cleanupCount++
        } catch {
            Write-Host "   [ERREUR] Fichiers en cours d'utilisation." -ForegroundColor Red
        }
    } else {
        Write-Host "   [INFO] Dossier introuvable." -ForegroundColor Gray
    }

    Write-Host ""
    if ($cleanupCount -gt 0) {
        Write-Host "SUCCÈS : LoginLight a été supprimé." -ForegroundColor Green
    } else {
        Write-Host "TERMINE : Rien à nettoyer." -ForegroundColor Yellow
    }

} catch {
    Write-Host "ERREUR FATALE : $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host ""
    Write-Host "Appuyez sur ENTREE pour fermer..." -ForegroundColor Cyan
    $null = [Console]::ReadLine()
}