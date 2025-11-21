# LoginLight - Intelligent Startup Splash Screen
# Displays full-screen video on all monitors with CPU-aware looping

# Set high priority for faster startup
$process = [System.Diagnostics.Process]::GetCurrentProcess()
$process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

# Force STA mode
if ($Host.Runspace.ApartmentState -ne "STA") {
  powershell.exe -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File $MyInvocation.MyCommand.Path
  exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# Configuration
$videoPath = Join-Path $PSScriptRoot "assets\login.mp4"
$initialWaitSeconds = 3
$cpuHighThreshold = 80
$cpuLowThreshold = 50
$cpuCheckIntervalMs = 1000
$fadeOutDurationSeconds = 1.5
$maxTimeoutSeconds = 60

# Script-level state
$script:windows = @()
$script:cpuMonitorActive = $false
$script:canExit = $false
$script:fadingOut = $false
$script:completedCount = 0
$script:timeoutTimer = $null

function Get-CpuUsage {
  $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
  if ($cpu) {
    return [math]::Round($cpu.CounterSamples[0].CookedValue, 2)
  }
  return 0
}

function Start-CpuMonitoring {
  $script:cpuMonitorActive = $true
  
  $timer = New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval = [TimeSpan]::FromMilliseconds($script:cpuCheckIntervalMs)
  
  $timer.Add_Tick({
    if (-not $script:cpuMonitorActive) {
      $this.Stop()
      return
    }
    
    $cpuUsage = Get-CpuUsage
    
    if ($cpuUsage -ge $script:cpuHighThreshold) {
      foreach ($win in $script:windows) {
        $mediaElement = $win.Tag
        if ($mediaElement.LoadedBehavior -ne [System.Windows.Controls.MediaState]::Manual) {
          $mediaElement.LoadedBehavior = [System.Windows.Controls.MediaState]::Manual
        }
        $mediaElement.Play()
      }
      $script:canExit = $false
    }
    elseif ($cpuUsage -le $script:cpuLowThreshold -and -not $script:fadingOut) {
      $script:canExit = $true
    }
  })
  
  $timer.Start()
}

function Start-FadeOut {
  if ($script:fadingOut) { return }
  $script:fadingOut = $true
  $script:cpuMonitorActive = $false
  $script:completedCount = 0
  
  if ($script:timeoutTimer) {
    $script:timeoutTimer.Stop()
  }
  
  $totalWindows = $script:windows.Count
  
  foreach ($win in $script:windows) {
    $storyboard = New-Object System.Windows.Media.Animation.Storyboard
    $fadeAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
    $fadeAnimation.From = 1.0
    $fadeAnimation.To = 0.0
    $fadeAnimation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds($script:fadeOutDurationSeconds))
    
    [System.Windows.Media.Animation.Storyboard]::SetTarget($fadeAnimation, $win)
    [System.Windows.Media.Animation.Storyboard]::SetTargetProperty($fadeAnimation, [System.Windows.PropertyPath]::new("Opacity"))
    
    $storyboard.Children.Add($fadeAnimation)
    
    $storyboard.Add_Completed({
      $script:completedCount++
      if ($script:completedCount -ge $totalWindows) {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
      }
    })
    
    $storyboard.Begin()
  }
}

function Create-FullScreenWindow {
  param([System.Windows.Forms.Screen]$screen)
  
  $window = New-Object System.Windows.Window
  $window.WindowStyle = [System.Windows.WindowStyle]::None
  $window.ResizeMode = [System.Windows.ResizeMode]::NoResize
  $window.Topmost = $true
  $window.Left = $screen.Bounds.Left
  $window.Top = $screen.Bounds.Top
  $window.Width = $screen.Bounds.Width
  $window.Height = $screen.Bounds.Height
  $window.WindowState = [System.Windows.WindowState]::Normal
  $window.Background = [System.Windows.Media.Brushes]::Black
  $window.ShowInTaskbar = $false
  $window.Cursor = [System.Windows.Input.Cursors]::None
  
  $grid = New-Object System.Windows.Controls.Grid
  
  $mediaElement = New-Object System.Windows.Controls.MediaElement
  $mediaElement.Source = [Uri]::new($videoPath)
  $mediaElement.LoadedBehavior = [System.Windows.Controls.MediaState]::Manual
  $mediaElement.UnloadedBehavior = [System.Windows.Controls.MediaState]::Close
  $mediaElement.Stretch = [System.Windows.Media.Stretch]::UniformToFill
  $mediaElement.Volume = 0.5
  
  $mediaElement.Add_MediaEnded({
    if ($script:canExit) {
      Start-FadeOut
    } else {
      $this.Position = [TimeSpan]::Zero
      $this.Play()
    }
  })
  
  $mediaElement.Add_MediaOpened({
    $this.Play()
  })
  
  $mediaElement.Add_MediaFailed({
    param($sender, $e)
    [void][System.Windows.MessageBox]::Show("Video failed to load: $($e.ErrorException.Message)", "LoginLight Error")
  })
  
  $mediaElement.Add_Loaded({
    $this.Play()
  })
  
  [void]$grid.Children.Add($mediaElement)
  $window.Content = $grid
  $window.Tag = $mediaElement
  
  return $window
}

# Main execution
try {
  if (-not (Test-Path $videoPath)) {
    [void][System.Windows.MessageBox]::Show("Video file not found: $videoPath`n`nPlease place login.mp4 in the assets folder.", "LoginLight Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
  }
  
  $screens = [System.Windows.Forms.Screen]::AllScreens
  
  foreach ($screen in $screens) {
    $window = Create-FullScreenWindow -screen $screen
    $script:windows += $window
  }
  
  foreach ($win in $script:windows) {
    [void]$win.Show()
  }
  
  $initialTimer = New-Object System.Windows.Threading.DispatcherTimer
  $initialTimer.Interval = [TimeSpan]::FromSeconds($initialWaitSeconds)
  $initialTimer.Add_Tick({
    $this.Stop()
    Start-CpuMonitoring
  })
  $initialTimer.Start()
  
  $script:timeoutTimer = New-Object System.Windows.Threading.DispatcherTimer
  $script:timeoutTimer.Interval = [TimeSpan]::FromSeconds($maxTimeoutSeconds)
  $script:timeoutTimer.Add_Tick({
    $this.Stop()
    Start-FadeOut
  })
  $script:timeoutTimer.Start()
  
  [System.Windows.Threading.Dispatcher]::Run()
}
catch {
  [void][System.Windows.MessageBox]::Show("Error: $($_.Exception.Message)`n`nStack: $($_.ScriptStackTrace)", "LoginLight Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
  exit 1
}
