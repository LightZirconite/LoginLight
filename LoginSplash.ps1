# LoginSplash.ps1 - V9 "Auto-Update Edition"
# Features: System Lock, Clean Exit, and BACKGROUND SELF-UPDATE
# Language: English

# 1. MAX PRIORITY
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

# 2. FORCE STA MODE
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

# SETTINGS
$minExecutionTime = 12        # Minimum lock time (seconds)
$cpuIdleThreshold = 30        # Unlock if CPU < 30%
$fadeOutDuration  = 0.8
$maxTimeoutSeconds = 90

# --- STATE ---
$script:windows = @()
$script:startTime = [DateTime]::Now
$script:canExit = $false
$script:isFadingOut = $false
$script:escCount = 0

# --- NATIVE API ---
$signature = @"
[DllImport("user32.dll")]
public static extern bool LockSetForegroundWindow(uint uLockCode);
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
"@
Add-Type -MemberDefinition $signature -Name "Win32" -Namespace Win32Functions

# --- UPDATE ENGINE (The Invisible Worker) ---
function Start-BackgroundUpdate {
    # This function creates a temporary script that runs AFTER we close.
    
    $updaterCode = @"
    param(`$TargetScript, `$TargetVideo, `$UrlScript, `$UrlVideo)
    
    # 1. Wait for the main app to close completely
    Start-Sleep -Seconds 5
    
    try {
        # 2. Update Script (Always check/overwrite small files)
        Invoke-WebRequest -Uri `$UrlScript -OutFile `$TargetScript -UseBasicParsing -ErrorAction Stop
        
        # 3. Update Video (Smart Check - Only if size differs)
        if (Test-Path `$TargetVideo) {
            `$localSize = (Get-Item `$TargetVideo).Length
            try {
                `$head = Invoke-WebRequest -Uri `$UrlVideo -Method Head -UseBasicParsing
                `$remoteSize = `$head.Headers.'Content-Length'
                
                if (`$remoteSize -ne `$null -and `$localSize -ne `$remoteSize) {
                    Invoke-WebRequest -Uri `$UrlVideo -OutFile `$TargetVideo -UseBasicParsing
                }
            } catch { 
                # Use existing video if network fails
            }
        }
    } catch {
        # Silent failure (internet issues), will try again next boot
    }
"@

    # Write the updater to the Temp folder
    $tempUpdater = Join-Path $env:TEMP "LoginLightUpdater.ps1"
    $updaterCode | Out-File -FilePath $tempUpdater -Encoding UTF8 -Force

    # Launch it hidden and detached
    Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tempUpdater`" -TargetScript `"$PSScriptRoot\LoginSplash.ps1`" -TargetVideo `"$videoPath`" -UrlScript `"$urlScript`" -UrlVideo `"$urlVideo`"" -WindowStyle Hidden
}

# --- DECISION ENGINE ---
function Start-DecisionEngine {
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(1000)
    $timer.Add_Tick({
        $elapsed = ([DateTime]::Now - $script:startTime).TotalSeconds
        
        if ($elapsed -ge $maxTimeoutSeconds) { Trigger-Exit; return }
        if ($elapsed -lt $minExecutionTime) { $script:canExit = $false; return }

        try {
            $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop -SampleInterval 1 -MaxSamples 1
            $usage = [math]::Round($cpu.CounterSamples.CookedValue, 0)
            if ($usage -le $cpuIdleThreshold) { $script:canExit = $true } else { $script:canExit = $false }
        } catch { $script:canExit = $false }
    })
    $timer.Start()
}

# --- EXIT SEQUENCE ---
function Trigger-Exit {
    if ($script:isFadingOut) { return }
    $script:isFadingOut = $true
    
    # 1. Unlock System Focus
    [Win32Functions.Win32]::LockSetForegroundWindow(2) # 2 = UNLOCK

    # 2. Launch the Update (Fire and Forget)
    Start-BackgroundUpdate

    $closedCount = 0
    foreach ($win in $script:windows) {
        $sb = New-Object System.Windows.Media.Animation.Storyboard
        
        $animFade = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration)))
        [System.Windows.Media.Animation.Storyboard]::SetTarget($animFade, $win)
        [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($animFade, [System.Windows.PropertyPath]::new("Opacity"))
        
        $media = $win.Tag
        if ($media) {
            $animVol = New-Object System.Windows.Media.Animation.DoubleAnimation($media.Volume, 0.0, [System.Windows.Duration]::new([TimeSpan]::FromSeconds($fadeOutDuration)))
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

    $mediaElement.Add_MediaEnded({
        if ($script:canExit) { Trigger-Exit } 
        else { $this.Position = [TimeSpan]::Zero; $this.Play() }
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

    # Lock System Focus
    [Win32Functions.Win32]::LockSetForegroundWindow(1) # 1 = LOCK

    Start-DecisionEngine

    # Backup Watchdog (Visual Layer only)
    $script:watchdogTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:watchdogTimer.Interval = [TimeSpan]::FromMilliseconds(100) 
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