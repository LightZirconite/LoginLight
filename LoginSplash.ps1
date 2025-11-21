# LoginSplash.ps1 - V6 "Clean Exit & Aggressive Focus"
# Language: English
# Changelog:
# - FIXED: "Black Screen of Death" (Windows now explicitly close after fade)
# - FIXED: Discord Popup (Z-Order enforcement is now aggressive)
# - IMPROVED: Startup smoothness (Pre-black screen)

# 1. PRIORITY SETTING
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

# 2. FORCE STA MODE (Essential for UI)
if ($Host.Runspace.ApartmentState -ne "STA") {
    powershell.exe -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $MyInvocation.MyCommand.Path
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# --- CONFIGURATION ---
$videoPath = Join-Path $PSScriptRoot "assets\login.mp4"

# SETTINGS
$minExecutionTime = 10        # Minimum time the screen MUST stay visible (seconds)
$cpuIdleThreshold = 30        # CPU must be under 30% to exit
$fadeOutDuration = 1.0        # Faster fade for snappier feel
$maxTimeoutSeconds = 60       # Absolute fail-safe timeout

# --- GLOBAL VARIABLES ---
$script:windows = @()
$script:startTime = [DateTime]::Now
$script:currentCpuUsage = 100 
$script:isFadingOut = $false
$script:escCount = 0
$script:completedFades = 0

# --- NATIVE WIN32 API (The "Aggressive" Tools) ---
$signature = @"
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);

[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
"@
Add-Type -MemberDefinition $signature -Name "Win32" -Namespace Win32Functions

# --- HELPERS ---

function Get-CpuSample {
    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
        $script:currentCpuUsage = [math]::Round($cpu.CounterSamples.CookedValue, 0)
    } catch {
        $script:currentCpuUsage = 100 # Assume busy on error
    }
}

# --- EXIT LOGIC (The Fix for Black Screen) ---
function Trigger-Exit {
    if ($script:isFadingOut) { return }
    $script:isFadingOut = $true
    
    # Stop the aggressive watchdog immediately so other apps can breathe
    if ($script:watchdogTimer) { $script:watchdogTimer.Stop() }
    
    foreach ($win in $script:windows) {
        $sb = New-Object System.Windows.Media.Animation.Storyboard
        
        # 1. Opacity Fade
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration)))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animFade, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animFade, [System.Windows.PropertyPath]::new("Opacity"))
        
        # 2. Volume Fade
        $media = $win.Tag
        if ($media) {
            $animVol = New-Object System.Windows.Media.Animation.DoubleAnimation($media.Volume, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration)))
            [System.Windows.Media.Animation.Storyboard]::SetTarget($animVol, $media)
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animVol, [System.Windows.PropertyPath]::new("Volume"))
            $sb.Children.Add($animVol)
        }
        
        $sb.Children.Add($animFade)
        
        # IMPORTANT: When animation finishes, DESTROY the window
        $sb.Add_Completed({
            $script:completedFades++
            $win.Close() # <--- THIS REMOVES THE GHOST WINDOW
            
            # If all windows are closed, kill the process
            if ($script:completedFades -ge $script:windows.Count) {
                [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
                [System.Environment]::Exit(0)
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
    $window.Background = "Black" # Starts black immediately
    $window.Left = $screen.Bounds.Left
    $window.Top = $screen.Bounds.Top
    $window.Width = $screen.Bounds.Width
    $window.Height = $screen.Bounds.Height
    $window.ShowInTaskbar = $false
    $window.Cursor = "None"

    # EMERGENCY KILL SWITCH (Press ESC 5 times)
    $window.Add_KeyDown({
        if ($_.Key -eq "Escape") {
            $script:escCount++
            if ($script:escCount -ge 5) { 
                $script:windows | ForEach-Object { $_.Close() }
                [System.Environment]::Exit(0) 
            }
        }
    })

    $grid = New-Object System.Windows.Controls.Grid
    
    $mediaElement = New-Object System.Windows.Controls.MediaElement
    $mediaElement.Source = [Uri]::new($videoPath)
    $mediaElement.LoadedBehavior = "Manual"
    $mediaElement.UnloadedBehavior = "Manual"
    $mediaElement.Stretch = "UniformToFill"
    $mediaElement.Volume = 0.6

    # LOGIC: LOOP vs EXIT
    $mediaElement.Add_MediaEnded({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        # Update CPU usage specifically at the end of the loop
        Get-CpuSample
        
        # CONDITIONS TO RESTART LOOP:
        # 1. Ran less than 10 seconds?
        # 2. OR CPU is busy (> 30%)?
        if ($elapsed -lt $minExecutionTime -or $script:currentCpuUsage -gt $cpuIdleThreshold) {
            $this.Position = [TimeSpan]::Zero
            $this.Play()
        } 
        else {
            Trigger-Exit
        }
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

    # --- WATCHDOG: AGGRESSIVE MODE ---
    # Runs every 100ms to fight Discord/Steam
    $script:watchdogTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:watchdogTimer.Interval = [TimeSpan]::FromMilliseconds(100)
    $script:watchdogTimer.Add_Tick({
        if (-not $script:isFadingOut) {
            # Safety Timeout
            if (([DateTime]::Now - $script:startTime).TotalSeconds -ge $maxTimeoutSeconds) {
                Trigger-Exit
            }

            foreach ($win in $script:windows) {
                $hwnd = new-object IntPtr $win.Handle
                
                # 1. Force TopMost Property
                if (-not $win.Topmost) { $win.Topmost = $true }
                
                # 2. Force Input Focus
                [Win32Functions.Win32]::SetForegroundWindow($hwnd) | Out-Null
                
                # 3. BRUTE FORCE: SetWindowPos (HWND_TOPMOST = -1)
                # This tells Windows Kernel: "Put this window on top NOW"
                [Win32Functions.Win32]::SetWindowPos($hwnd, [IntPtr]::new(-1), 0, 0, 0, 0, 3) | Out-Null
            }
        }
    })
    $script:watchdogTimer.Start()

    [System.Windows.Threading.Dispatcher]::Run()
} catch {
    # If anything crashes, ensure we exit cleanly
    [System.Environment]::Exit(1)
}