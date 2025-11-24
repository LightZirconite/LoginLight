# LoginSplash.ps1 - V10 "Smart Edition"
# Features: System Lock, Clean Exit, Background Update, & Smart CPU Monitoring
# Language: English (Logic), French comments

# 1. PRIORITÉ MAXIMALE
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

# 2. FORCER LE MODE STA (Requis pour WPF)
if ($Host.Runspace.ApartmentState -ne "STA") {
    powershell.exe -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $MyInvocation.MyCommand.Path
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# --- CONFIGURATION ---
$installDir = $PSScriptRoot
$assetsDir  = Join-Path $installDir "assets"
$videoPath  = Join-Path $assetsDir "login.mp4"

# UPDATE CONFIGURATION (Raw GitHub URLs)
$ghBase = "https://raw.githubusercontent.com/LightZirconite/LoginLight/refs/heads/main"
$urlScript = "$ghBase/LoginSplash.ps1"
$urlVideo  = "$ghBase/assets/login.mp4"

# --- REGLAGES INTELLIGENTS ---
$minExecutionTime  = 10      # Temps mini (secondes) avant même de penser à sortir
$cpuIdleThreshold  = 40      # Si le CPU est sous 40%
$cpuStableCount    = 3       # Il doit rester bas pendant 3 vérifications de suite (évite les faux positifs)
$maxTimeoutSeconds = 90      # Sécurité : on sort quoiqu'il arrive après 90s
$checkInterval     = 1.0     # Vérifier chaque seconde

# --- ETAT DU SCRIPT ---
$script:windows = @()
$script:startTime = [DateTime]::Now
$script:canExit = $false
$script:isFadingOut = $false
$script:escCount = 0
$script:lowCpuStreak = 0 # Compteur de stabilité CPU

# --- COMPTEUR DE PERFORMANCE (.NET - Beaucoup plus rapide que Get-Counter) ---
try {
    $script:cpuCounter = New-Object System.Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
    $null = $script:cpuCounter.NextValue() # La première valeur est toujours 0, on l'ignore
} catch {
    # Fallback si erreur WMI
    $script:cpuCounter = $null
}

# --- NATIVE API (Lock Input / Topmost) ---
$signature = @"
[DllImport("user32.dll")]
public static extern bool LockSetForegroundWindow(uint uLockCode);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
"@
Add-Type -MemberDefinition $signature -Name "Win32" -Namespace Win32Functions

# --- MOTEUR DE MISE A JOUR (Invisible) ---
function Start-BackgroundUpdate {
    $updaterCode = @"
    param(`$TargetScript, `$TargetVideo, `$UrlScript, `$UrlVideo)
    Start-Sleep -Seconds 5
    try {
        Invoke-WebRequest -Uri `$UrlScript -OutFile `$TargetScript -UseBasicParsing -ErrorAction Stop
        if (Test-Path `$TargetVideo) {
            `$localSize = (Get-Item `$TargetVideo).Length
            try {
                `$head = Invoke-WebRequest -Uri `$UrlVideo -Method Head -UseBasicParsing
                `$remoteSize = `$head.Headers.'Content-Length'
                if (`$remoteSize -ne `$null -and `$localSize -ne `$remoteSize) {
                    Invoke-WebRequest -Uri `$UrlVideo -OutFile `$TargetVideo -UseBasicParsing
                }
            } catch {}
        }
    } catch {}
"@
    $tempUpdater = Join-Path $env:TEMP "LoginLightUpdater.ps1"
    $updaterCode | Out-File -FilePath $tempUpdater -Encoding UTF8 -Force
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tempUpdater`" -TargetScript `"$PSScriptRoot\LoginSplash.ps1`" -TargetVideo `"$videoPath`" -UrlScript `"$urlScript`" -UrlVideo `"$urlVideo`"" -WindowStyle Hidden
}

# --- MOTEUR DE DECISION (La boucle principale) ---
function Start-DecisionEngine {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds($checkInterval)
    
    $timer.Add_Tick({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        # 1. Sécurité absolue (Time out)
        if ($elapsed -ge $maxTimeoutSeconds) { Trigger-Exit; return }
        
        # 2. Si on n'a pas encore atteint le temps minimum, on ne fait rien
        if ($elapsed -lt $minExecutionTime) { return }

        # 3. Analyse CPU (Méthode Rapide)
        try {
            if ($script:cpuCounter) {
                $currentCpu = $script:cpuCounter.NextValue()
            } else {
                $currentCpu = 100 # Si le compteur a échoué, on force l'attente
            }
            
            # Logique "Smart" : Est-ce que le PC est calme ?
            if ($currentCpu -le $cpuIdleThreshold) {
                $script:lowCpuStreak++
            } else {
                $script:lowCpuStreak = 0 # Reset si le CPU remonte
            }

            # Si le CPU est calme depuis assez longtemps -> On autorise la sortie
            if ($script:lowCpuStreak -ge $cpuStableCount) {
                $script:canExit = $true
            }

        } catch { 
            # En cas d'erreur, on sort par sécurité
            $script:canExit = $true 
        }
    })
    $timer.Start()
}

# --- SEQUENCE DE SORTIE ---
function Trigger-Exit {
    if ($script:isFadingOut) { return }
    $script:isFadingOut = $true
    
    # 1. Déverrouillage Focus
    [Win32Functions.Win32]::LockSetForegroundWindow(2) 

    # 2. Lancer la mise à jour
    Start-BackgroundUpdate

    $closedCount = 0
    foreach ($win in $script:windows) {
        $sb = New-Object System.Windows.Media.Animation.Storyboard
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds(0.8)))
        
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animFade, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animFade, [System.Windows.PropertyPath]::new("Opacity"))
        
        # Fade Volume aussi
        $media = $win.Tag
        if ($media) {
            $animVol = New-Object System.Windows.Media.Animation.DoubleAnimation($media.Volume, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds(0.8)))
            [System.Windows.Media.Animation.Storyboard]::SetTarget($animVol, $media)
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animVol, [System.Windows.PropertyPath]::new("Volume"))
            $sb.Children.Add($animVol)
        }
        
        $sb.Children.Add($animFade)
        $sb.Add_Completed({
            $win.Close()
            $closedCount++
            if ($closedCount -ge $script:windows.Count) {
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
                [System.Environment]::Exit(0)
            }
        })
        $sb.Begin()
    }
}

function Create-Window {
    param([System.Windows.Forms.Screen]$screen)

    $window = New-Object System.Windows.Window
    $window.WindowStyle = "None"
    $window.ResizeMode = "NoResize"
    $window.Topmost = $true
    $window.Background = "Black"
    $window.Left = $screen.Bounds.Left
    $window.Top = $screen.Bounds.Top
    $window.Width = $screen.Bounds.Width
    $window.Height = $screen.Bounds.Height
    $window.ShowInTaskbar = $false
    $window.Cursor = "None"

    # Sortie d'urgence (5x Echap)
    $window.Add_KeyDown({
        if ($_.Key -eq "Escape") {
            $script:escCount++
            if ($script:escCount -ge 5) { [System.Environment]::Exit(0) }
        }
    })

    $grid = New-Object System.Windows.Controls.Grid
    $mediaElement = New-Object System.Windows.Controls.MediaElement
    $mediaElement.Source = [Uri]::new($videoPath)
    $mediaElement.LoadedBehavior = "Manual"
    $mediaElement.UnloadedBehavior = "Manual"
    $mediaElement.Stretch = "UniformToFill"
    $mediaElement.Volume = 0.6

    # Logique de boucle vidéo
    $mediaElement.Add_MediaEnded({
        if ($script:canExit) { 
            Trigger-Exit 
        } else { 
            $this.Position = [TimeSpan]::Zero
            $this.Play() 
        }
    })
    
    $mediaElement.Add_MediaFailed({ Trigger-Exit })
    $mediaElement.Add_Loaded({ $this.Play() })
    
    [void]$grid.Children.Add($mediaElement)
    $window.Content = $grid
    $window.Tag = $mediaElement
    return $window
}

# --- MAIN ---
try {
    if (-not (Test-Path $videoPath)) { exit }
    
    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($screen in $screens) {
        $win = Create-Window -screen $screen
        $script:windows += $win
        [void]$win.Show()
    }

    # Verrouiller le système au premier plan
    [Win32Functions.Win32]::LockSetForegroundWindow(1)

    Start-DecisionEngine

    # Watchdog visuel (Garde la fenêtre au dessus de tout)
    $script:watchdogTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:watchdogTimer.Interval = [TimeSpan]::FromMilliseconds(200) 
    $script:watchdogTimer.Add_Tick({
        if (-not $script:isFadingOut) {
            foreach ($win in $script:windows) {
                $hwnd = new-object IntPtr $win.Handle
                if (-not $win.Topmost) { $win.Topmost = $true }
                [Win32Functions.Win32]::SetWindowPos($hwnd, [IntPtr]::new(-1), 0, 0, 0, 0, 3) | Out-Null
            }
        }
    })
    $script:watchdogTimer.Start()

    [System.Windows.Threading.Dispatcher]::Run()
} catch { [System.Environment]::Exit(1) }