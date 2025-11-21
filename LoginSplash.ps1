# LoginSplash.ps1 - V3 Ultimate "Smart Warm-up"
# High-Performance Startup Splash Screen with Intelligent CPU Monitoring
# ---------------------------------------------------------

# 1. IMMEDIATE PRIORITY BOOST
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

# 2. FORCE STA MODE (Required for WPF)
if ($Host.Runspace.ApartmentState -ne "STA") {
    powershell.exe -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $MyInvocation.MyCommand.Path
    exit
}

# Load WPF and WinForms Assemblies
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# --- INTELLIGENT CONFIGURATION ---
$videoPath = Join-Path $PSScriptRoot "assets\login.mp4"

# CPU THRESHOLDS
$cpuLowThreshold = 35          # If CPU drops below 35%, consider PC ready to use

# TIMING LOGIC (The Fix)
$minVideoDuration = 5          # Video must play for at least 5 seconds no matter what
$bootGracePeriod = 10          # IMPORTANT: Ignore CPU for the first 10 seconds
                               # This allows Steam/Discord time to START loading and spike the CPU.
                               
$fadeOutDuration = 1.5         # Fade out speed
$maxTimeoutSeconds = 60        # Safety kill-switch (1 minute max)

# --- GLOBAL STATE ---
$script:windows = @()
$script:canExit = $false
$script:fadingOut = $false
$script:startTime = [DateTime]::Now
$script:escCount = 0 

# --- NATIVE METHODS (The Watchdog Logic) ---
$signature = @"
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
"@
Add-Type -MemberDefinition $signature -Name "Win32" -Namespace Win32Functions

function Get-CpuUsage {
    try {
        # Get a quick sample of CPU usage
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
        return [math]::Round($cpu.CounterSamples.CookedValue, 0)
    }
    catch { 
        return 100 # Assume high load on error
    }
}

function Start-FadeOut {
    if ($script:fadingOut) { return }
    $script:fadingOut = $true
    
    if ($script:monitoringTimer) { $script:monitoringTimer.Stop() }
    if ($script:zOrderTimer) { $script:zOrderTimer.Stop() }

    $completedCount = 0
    $totalWindows = $script:windows.Count

    foreach ($win in $script:windows) {
        $storyboard = New-Object System.Windows.Media.Animation.Storyboard
        
        # 1. Visual Fade
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animFade.From = 1.0
        $animFade.To = 0.0
        $animFade.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animFade, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animFade, [System.Windows.PropertyPath]::new("Opacity"))
        
        # 2. Audio Fade
        $mediaElement = $win.Tag
        if ($mediaElement) {
            $animVol = New-Object System.Windows.Media.Animation.DoubleAnimation
            $animVol.From = $mediaElement.Volume
            $animVol.To = 0.0
            $animVol.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration))
            [System.Windows.Media.Animation.Storyboard]::SetTarget($animVol, $mediaElement)
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animVol, [System.Windows.PropertyPath]::new("Volume"))
            $storyboard.Children.Add($animVol)
        }

        $storyboard.Children.Add($animFade)
        $storyboard.Add_Completed({
            $completedCount++
            if ($completedCount -ge $totalWindows) {
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
            }
        })
        $storyboard.Begin()
    }
}

function Create-BlackWindow {
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

    # KILL SWITCH: Press ESC 5 times
    $window.Add_KeyDown({
        if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
            $script:escCount++
            if ($script:escCount -ge 5) { 
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() 
            }
        }
    })

    $grid = New-Object System.Windows.Controls.Grid
    
    $mediaElement = New-Object System.Windows.Controls.MediaElement
    $mediaElement.Source = [Uri]::new($videoPath)
    $mediaElement.LoadedBehavior = [System.Windows.Controls.MediaState]::Manual
    $mediaElement.UnloadedBehavior = [System.Windows.Controls.MediaState]::Close
    $mediaElement.Stretch = [System.Windows.Media.Stretch]::UniformToFill
    $mediaElement.Volume = 0.6

    # Video Loop Logic
    $mediaElement.Add_MediaEnded({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        # Only exit if CPU is low AND we passed the minimum visual duration
        if ($script:canExit -and $elapsed -ge $minVideoDuration) {
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
        $win = Create-BlackWindow -screen $screen
        $script:windows += $win
        [void]$win.Show()
    }

    # --- TIMER 1: INTELLIGENT MONITORING ---
    $script:monitoringTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:monitoringTimer.Interval = [TimeSpan]::FromMilliseconds(1000)
    $script:monitoringTimer.Add_Tick({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        # 1. Safety Timeout
        if ($elapsed -ge $maxTimeoutSeconds) { Start-FadeOut; return }

        # 2. WARM-UP PHASE (The Fix)
        # If we are in the first 10 seconds ($bootGracePeriod), DO NOT check CPU.
        # Just assume we are "busy" to let other apps start.
        if ($elapsed -lt $bootGracePeriod) {
            $script:canExit = $false
            return
        }

        # 3. ACTIVE MONITORING PHASE
        # Now that 10 seconds have passed, we trust the CPU reading.
        $usage = Get-CpuUsage
        if ($usage -le $cpuLowThreshold) { 
            $script:canExit = $true 
        } else { 
            $script:canExit = $false 
        }
    })
    $script:monitoringTimer.Start()

    # --- TIMER 2: WATCHDOG (Always on top) ---
    $script:zOrderTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:zOrderTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:zOrderTimer.Add_Tick({
        if (-not $script:fadingOut) {
            foreach ($win in $script:windows) {
                $hwnd = new-object IntPtr $win.Handle
                if (-not $win.Topmost) { $win.Topmost = $true }
                [Win32Functions.Win32]::SetForegroundWindow($hwnd) | Out-Null
                [Win32Functions.Win32]::SetWindowPos($hwnd, [IntPtr]::new(-1), 0, 0, 0, 0, 3) | Out-Null
            }
        }
    })
    $script:zOrderTimer.Start()

    [System.Windows.Threading.Dispatcher]::Run()
}
catch { exit }