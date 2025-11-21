# LoginSplash.ps1 - Ultimate Edition
# High-Performance Startup Splash Screen with CPU Monitoring
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

# --- CONFIGURATION ---
$videoPath = Join-Path $PSScriptRoot "assets\login.mp4"
$cpuHighThreshold = 80         # If CPU > 80%, keep playing
$cpuLowThreshold = 40          # If CPU < 40%, consider PC ready
$minDurationSeconds = 4        # Minimum video duration
$fadeOutDuration = 1.5         # Fade out speed
$maxTimeoutSeconds = 45        # Safety kill-switch time

# --- GLOBAL STATE ---
$script:windows = @()
$script:canExit = $false
$script:fadingOut = $false
$script:startTime = [DateTime]::Now
$script:escCount = 0  # Safety counter for Escape key

# --- NATIVE METHODS (The Watchdog Logic) ---
# We import user32.dll functions to aggressively force the window on top
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
    
    # Stop monitoring timers
    if ($script:monitoringTimer) { $script:monitoringTimer.Stop() }
    if ($script:zOrderTimer) { $script:zOrderTimer.Stop() }

    $completedCount = 0
    $totalWindows = $script:windows.Count

    foreach ($win in $script:windows) {
        $storyboard = New-Object System.Windows.Media.Animation.Storyboard
        
        # 1. Visual Fade (Opacity)
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animFade.From = 1.0
        $animFade.To = 0.0
        $animFade.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animFade, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animFade, [System.Windows.PropertyPath]::new("Opacity"))
        
        # 2. Audio Fade (Volume)
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
                # Full Shutdown
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

    # SAFETY KILL SWITCH: Press ESC 5 times to force exit
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
        
        # Exit only if CPU is low AND min duration passed
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

# --- MAIN EXECUTION ---
try {
    if (-not (Test-Path $videoPath)) { exit }

    # Launch windows on all screens
    $screens = [System.Windows.Forms.Screen]::AllScreens
    foreach ($screen in $screens) {
        $win = Create-BlackWindow -screen $screen
        $script:windows += $win
        [void]$win.Show()
    }

    # --- TIMER 1: CPU MONITORING ---
    $script:monitoringTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:monitoringTimer.Interval = [TimeSpan]::FromMilliseconds(1500)
    $script:monitoringTimer.Add_Tick({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        # Absolute Timeout
        if ($elapsed -ge $maxTimeoutSeconds) { Start-FadeOut; return }

        # Check CPU only after initial warm-up
        if ($elapsed -ge 3) {
            $usage = Get-CpuUsage
            if ($usage -le $cpuLowThreshold) { 
                $script:canExit = $true 
            } else { 
                $script:canExit = $false 
            }
        }
    })
    $script:monitoringTimer.Start()

    # --- TIMER 2: THE WATCHDOG (Z-Order Enforcer) ---
    # This aggressively keeps the window on top of Discord/Steam/etc.
    $script:zOrderTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:zOrderTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:zOrderTimer.Add_Tick({
        if (-not $script:fadingOut) {
            foreach ($win in $script:windows) {
                $hwnd = new-object IntPtr $win.Handle
                
                # Method A: Standard TopMost
                if (-not $win.Topmost) { $win.Topmost = $true }
                
                # Method B: Force Foreground (Input focus)
                [Win32Functions.Win32]::SetForegroundWindow($hwnd) | Out-Null
                
                # Method C: Force Window Position (Visual Layer)
                # HWND_TOPMOST = -1, SWP_NOMOVE | SWP_NOSIZE = 0x0003
                [Win32Functions.Win32]::SetWindowPos($hwnd, [IntPtr]::new(-1), 0, 0, 0, 0, 3) | Out-Null
            }
        }
    })
    $script:zOrderTimer.Start()

    # Start UI Loop
    [System.Windows.Threading.Dispatcher]::Run()
}
catch {
    exit
}