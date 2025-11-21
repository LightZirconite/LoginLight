# LoginSplash.ps1 - Ultimate Edition
# Optimisé pour bloquer les autres fenêtres au démarrage

# 1. Boost de priorité immédiat
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

# 2. Vérification STA
if ($Host.Runspace.ApartmentState -ne "STA") {
    powershell.exe -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $MyInvocation.MyCommand.Path
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# --- CONFIGURATION ---
$videoPath = Join-Path $PSScriptRoot "assets\login.mp4"
$cpuHighThreshold = 80
$cpuLowThreshold = 40
$minDurationSeconds = 4
$fadeOutDuration = 1.5
$maxTimeoutSeconds = 45

# --- VARIABLES GLOBALES ---
$script:windows = @()
$script:canExit = $false
$script:fadingOut = $false
$script:startTime = [DateTime]::Now
$script:escCount = 0  # Pour le Kill-Switch

# Import pour forcer le premier plan (API Windows)
$signature = @"
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);
"@
Add-Type -MemberDefinition $signature -Name "Win32" -Namespace Win32Functions

function Get-CpuUsage {
    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
        return [math]::Round($cpu.CounterSamples.CookedValue, 0)
    }
    catch { return 100 }
}

function Start-FadeOut {
    if ($script:fadingOut) { return }
    $script:fadingOut = $true
    
    # Arrêt des surveillances
    if ($script:monitoringTimer) { $script:monitoringTimer.Stop() }
    if ($script:zOrderTimer) { $script:zOrderTimer.Stop() }

    $completedCount = 0
    $totalWindows = $script:windows.Count

    foreach ($win in $script:windows) {
        $storyboard = New-Object System.Windows.Media.Animation.Storyboard
        
        # Animation Opacité (Visuel)
        $fadeVisuel = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fadeVisuel.From = 1.0
        $fadeVisuel.To = 0.0
        $fadeVisuel.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($fadeVisuel, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($fadeVisuel, [System.Windows.PropertyPath]::new("Opacity"))
        
        # Animation Volume (Audio - baisse le son progressivement)
        $mediaElement = $win.Tag
        if ($mediaElement) {
            $fadeAudio = New-Object System.Windows.Media.Animation.DoubleAnimation
            $fadeAudio.From = $mediaElement.Volume
            $fadeAudio.To = 0.0
            $fadeAudio.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration))
            [System.Windows.Media.Animation.Storyboard]::SetTarget($fadeAudio, $mediaElement)
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($fadeAudio, [System.Windows.PropertyPath]::new("Volume"))
            $storyboard.Children.Add($fadeAudio)
        }

        $storyboard.Children.Add($fadeVisuel)
        
        $storyboard.Add_Completed({
            $completedCount++
            if ($completedCount -ge $totalWindows) {
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
            }
        })
        $storyboard.Begin()
    }
}

function Create-Window {
    param([System.Windows.Forms.Screen]$screen)

    $window = New-Object System.Windows.Window
    $window.WindowStyle = [System.Windows.WindowStyle]::None
    $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
    $window.Topmost = $true
    $window.Background = [System.Windows.Media.Brushes]::Black
    $window.Left = $screen.Bounds.Left
    $window.Top = $screen.Bounds.Top
    $window.Width = $screen.Bounds.Width
    $window.Height = $screen.Bounds.Height
    $window.ShowInTaskbar = $false
    $window.Cursor = [System.Windows.Input.Cursors]::None

    # Gestion du Kill-Switch (Appuyer 5 fois sur Echap)
    $window.Add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
            $script:escCount++
            if ($script:escCount -ge 5) { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() }
        }
    })

    $grid = New-Object System.Windows.Controls.Grid
    
    $mediaElement = New-Object System.Windows.Controls.MediaElement
    $mediaElement.Source = [Uri]::new($videoPath)
    $mediaElement.LoadedBehavior = [System.Windows.Controls.MediaState]::Manual
    $mediaElement.UnloadedBehavior = [System.Windows.Controls.MediaState]::Close
    $mediaElement.Stretch = [System.Windows.Media.Stretch]::UniformToFill
    $mediaElement.Volume = 0.5 # Volume par défaut

    $mediaElement.Add_MediaEnded({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        if ($script:canExit -and $elapsed -ge $minDurationSeconds) {
            Start-FadeOut
        } else {
            $this.Position = [TimeSpan]::Zero
            $this.Play()
        }
    })
    $mediaElement.Add_Loaded({ $this.Play() })
    
    [void]$grid.Children.Add($mediaElement)
    $window.Content = $grid
    $window.Tag = $mediaElement
    return $window
}

try {
    if (-not (Test-Path $videoPath)) { exit }

    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($screen in $screens) {
        $win = Create-Window -screen $screen
        $script:windows += $win
        [void]$win.Show()
    }

    # Timer de surveillance CPU
    $script:monitoringTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:monitoringTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
    $script:monitoringTimer.Add_Tick({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        if ($elapsed -ge $maxTimeoutSeconds) { Start-FadeOut; return }
        
        if ($elapsed -ge 3) {
            $usage = Get-CpuUsage
            if ($usage -le $cpuLowThreshold) { $script:canExit = $true } 
            else { $script:canExit = $false }
        }
    })
    $script:monitoringTimer.Start()

    # TIMER WATCHDOG (Le garde du corps)
    # Vérifie 4 fois par seconde si la fenêtre est bien devant
    $script:zOrderTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:zOrderTimer.Interval = [TimeSpan]::FromMilliseconds(250)
    $script:zOrderTimer.Add_Tick({
        if (-not $script:fadingOut) {
            foreach ($win in $script:windows) {
                if (-not $win.Topmost) { $win.Topmost = $true }
                # Force brute pour passer devant Discord/Steam
                $hwnd = new-object IntPtr $win.Handle
                [Win32Functions.Win32]::SetForegroundWindow($hwnd) | Out-Null
            }
        }
    })
    $script:zOrderTimer.Start()

    [System.Windows.Threading.Dispatcher]::Run()
}
catch { exit }