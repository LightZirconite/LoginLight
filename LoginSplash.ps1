# LoginSplash.ps1 - V5 "Loop Decision" Edition
# Logic: Decision to exit is made ONLY when video ends to ensure smooth looping.
# Language: English

# 1. PRIORITY & SETUP
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

if ($Host.Runspace.ApartmentState -ne "STA") {
    powershell.exe -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $MyInvocation.MyCommand.Path
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# --- CONFIGURATION ---
$videoPath = Join-Path $PSScriptRoot "assets\login.mp4"

# THRESHOLDS
$minExecutionTime = 10        # MANDATORY: Script stays alive for 10s minimum
$cpuIdleThreshold = 30        # CPU must be UNDER 30% to exit
$fadeOutDuration = 1.5        # Fade speed
$maxTimeoutSeconds = 60       # Absolute safety stop

# --- VARIABLES ---
$script:windows = @()
$script:startTime = [DateTime]::Now
$script:currentCpuUsage = 100 # We start assuming CPU is busy
$script:isFadingOut = $false
$script:escCount = 0

# --- CPU MONITOR (Runs in background) ---
# It simply updates the $script:currentCpuUsage variable. It does NOT decide to exit.
function Start-CpuTracker {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        try {
            $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
            $script:currentCpuUsage = [math]::Round($cpu.CounterSamples.CookedValue, 0)
        } catch {
            $script:currentCpuUsage = 100 # If error, assume busy
        }
        
        # Safety Timeout (Force exit if > 60s)
        $totalRunTime = ([DateTime]::Now - $script:startTime).TotalSeconds
        if ($totalRunTime -ge $maxTimeoutSeconds -and -not $script:isFadingOut) {
            Start-FadeOut
        }
    })
    $timer.Start()
}

# --- WATCHDOG (Keeps window on top) ---
Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);' -Name "Win32" -Namespace Win32Functions
function Start-Watchdog {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({
        if (-not $script:isFadingOut) {
            foreach ($win in $script:windows) {
                if (-not $win.Topmost) { $win.Topmost = $true }
                $hwnd = new-object IntPtr $win.Handle
                [Win32Functions.Win32]::SetForegroundWindow($hwnd) | Out-Null
            }
        }
    })
    $timer.Start()
}

# --- FADE OUT LOGIC ---
function Start-FadeOut {
    if ($script:isFadingOut) { return }
    $script:isFadingOut = $true
    
    $completed = 0
    foreach ($win in $script:windows) {
        $sb = New-Object System.Windows.Media.Animation.Storyboard
        
        # Opacity Fade
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration)))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animFade, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animFade, [System.Windows.PropertyPath]::new("Opacity"))
        
        # Volume Fade
        $media = $win.Tag
        $animVol = New-Object System.Windows.Media.Animation.DoubleAnimation($media.Volume, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration)))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animVol, $media)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animVol, [System.Windows.PropertyPath]::new("Volume"))
        
        $sb.Children.Add($animFade)
        $sb.Children.Add($animVol)
        
        $sb.Add_Completed({
            $completed++
            if ($completed -ge $script:windows.Count) {
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
            }
        })
        $sb.Begin()
    }
}

# --- WINDOW CREATION ---
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

    # Kill Switch (5x Esc)
    $window.Add_KeyDown({
        if ($_.Key -eq "Escape") {
            $script:escCount++
            if ($script:escCount -ge 5) { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown() }
        }
    })

    $grid = New-Object System.Windows.Controls.Grid
    
    $mediaElement = New-Object System.Windows.Controls.MediaElement
    $mediaElement.Source = [Uri]::new($videoPath)
    $mediaElement.LoadedBehavior = "Manual"
    $mediaElement.UnloadedBehavior = "Manual" # Important: prevents auto-close
    $mediaElement.Stretch = "UniformToFill"
    $mediaElement.Volume = 0.6

    # --- THE CORE LOGIC IS HERE ---
    $mediaElement.Add_MediaEnded({
        $elapsedSeconds = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        # DECISION TREE:
        # 1. Have we waited enough time? (10 seconds mandatory)
        if ($elapsedSeconds -lt $minExecutionTime) {
            $this.Position = [TimeSpan]::Zero
            $this.Play()
            return
        }

        # 2. Is the CPU calm enough? (< 30%)
        if ($script:currentCpuUsage -gt $cpuIdleThreshold) {
            # CPU is busy (apps loading), so we LOOP again
            $this.Position = [TimeSpan]::Zero
            $this.Play()
            return
        }

        # 3. If Time is OK and CPU is OK -> Fade Out
        Start-FadeOut
    })
    
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

    Start-CpuTracker # Starts updating $script:currentCpuUsage
    Start-Watchdog   # Starts forcing window on top

    [System.Windows.Threading.Dispatcher]::Run()
} catch { exit }