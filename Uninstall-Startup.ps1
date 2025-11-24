# Uninstall-Startup.ps1
# Version: V2 "Debug Edition" (Ne se ferme pas en cas d'erreur)
# Language: English (Logic), French (Messages)

# --- 0. AUTO-ELEVATION ADMIN ---
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Droits Admin requis. Relance du script..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    exit
}

# --- BLOC DE SÉCURITÉ PRINCIPAL ---
try {
    Clear-Host
    Write-Host "=== LoginLight Désinstallateur ===" -ForegroundColor Cyan
    Write-Host ""

    # CONFIGURATION
    $appName = "LoginLight"
    $taskName = "LoginLightSystem"
    $installDir = Join-Path $env:LOCALAPPDATA $appName
    $startupFolder = [Environment]::GetFolderPath('Startup')
    $legacyShortcut = Join-Path $startupFolder "$appName.lnk"
    $cleanupCount = 0

    # --- 1. SUPPRESSION TÂCHE PLANIFIÉE ---
    Write-Host "1. Vérification de la tâche planifiée..." -ForegroundColor Yellow
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Host "   [OK] Tâche système supprimée." -ForegroundColor Green
            $cleanupCount++
        } else {
            Write-Host "   [INFO] Aucune tâche trouvée (déjà supprimée ?)." -ForegroundColor Gray
        }
    } catch {
        Write-Host "   [ERREUR TÂCHE] $($_.Exception.Message)" -ForegroundColor Red
    }

    # --- 2. SUPPRESSION RACCOURCI ---
    Write-Host "2. Vérification des raccourcis..." -ForegroundColor Yellow
    if (Test-Path $legacyShortcut) {
        Remove-Item $legacyShortcut -Force -ErrorAction SilentlyContinue
        Write-Host "   [OK] Raccourci de démarrage supprimé." -ForegroundColor Green
        $cleanupCount++
    } else {
        Write-Host "   [INFO] Aucun raccourci trouvé." -ForegroundColor Gray
    }

    # --- 3. SUPPRESSION FICHIERS ---
    Write-Host "3. Nettoyage des fichiers..." -ForegroundColor Yellow
    if (Test-Path $installDir) {
        # Tentative de tuer les processus fantômes qui bloqueraient les fichiers
        try {
            $myPid = $PID
            Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $myPid -and $_.MainWindowTitle -eq "" } | Stop-Process -Force -ErrorAction SilentlyContinue
        } catch {}

        try {
            Remove-Item $installDir -Recurse -Force -ErrorAction Stop
            Write-Host "   [OK] Dossier d'installation supprimé ($installDir)." -ForegroundColor Green
            $cleanupCount++
        } catch {
            Write-Host "   [ERREUR FICHIER] Impossible de supprimer le dossier." -ForegroundColor Red
            Write-Host "   Détail : $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "   -> Vérifie qu'aucun script n'est encore lancé." -ForegroundColor Yellow
        }
    } else {
        Write-Host "   [INFO] Dossier d'installation introuvable." -ForegroundColor Gray
    }

    Write-Host ""
    if ($cleanupCount -gt 0) {
        Write-Host "SUCCÈS : Tout a été nettoyé." -ForegroundColor Green
    } else {
        Write-Host "TERMINE : Rien n'a été trouvé (déjà propre)." -ForegroundColor Yellow
    }

} catch {
    # C'est ici qu'on attrape les erreurs fatales imprévues
    Write-Host ""
    Write-Host "!!! ERREUR FATALE !!!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
} finally {
    # CE BLOC S'EXECUTE TOUJOURS, MÊME SI CA PLANTE
    Write-Host ""
    Write-Host "Appuyez sur ENTREE pour fermer..." -ForegroundColor Cyan
    $null = [Console]::ReadLine()
}