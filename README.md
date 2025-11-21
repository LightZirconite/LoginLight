# LoginLight 🎬

**Intelligent startup splash screen for Windows** - Full-screen video display with CPU-aware adaptive looping.

## Features

✅ **Auto-start at Windows login** (fastest possible startup)  
✅ **Full-screen on all monitors** (multi-display support)  
✅ **CPU-aware intelligent looping** (adapts to system load)  
✅ **Smooth fade-out transition** (professional exit)  
✅ **Native PowerShell + WPF** (no external dependencies)

---

## How It Works

1. **Startup**: Launches automatically when you log into Windows
2. **Display**: Shows `login.mp4` full-screen on all monitors
3. **Initial wait**: Plays for 5 seconds minimum
4. **CPU monitoring**: 
   - If CPU ≥ 80% → **loops video** (system busy with startup tasks)
   - If CPU ≤ 50% → **prepares to exit** (system ready)
5. **Exit**: Waits for video to complete, then fades out smoothly

---

## Installation

### 1. Add Your Video

Place your video file as `login.mp4` in the `assets` folder:

```
LoginLight/
├── assets/
│   └── login.mp4  ← Your video here
├── LoginSplash.ps1
├── Install-Startup.ps1
└── Uninstall-Startup.ps1
```

**Supported formats**: MP4, AVI, WMV (MP4 recommended)

### 2. Enable Startup

Right-click `Install-Startup.ps1` → **Run with PowerShell**

This registers the app to start automatically at Windows login.

### 3. Test

Log out and log back in, or run manually:

```powershell
powershell -ExecutionPolicy Bypass -File LoginSplash.ps1
```

---

## Uninstallation

Right-click `Uninstall-Startup.ps1` → **Run with PowerShell**

---

## Configuration

Edit `LoginSplash.ps1` to customize behavior:

```powershell
$initialWaitSeconds = 5           # Minimum display time
$cpuHighThreshold = 80             # CPU % to keep looping
$cpuLowThreshold = 50              # CPU % to allow exit
$cpuCheckIntervalMs = 1000         # CPU check frequency (ms)
$fadeOutDurationSeconds = 1.5      # Fade-out animation duration
```

---

## Technical Details

### Why CPU Monitoring?

At Windows startup, many background services and applications load simultaneously, causing CPU spikes. This app intelligently waits for the system to stabilize before closing, ensuring:

- User sees the splash screen during the "busy" startup phase
- Smooth transition to desktop when system is ready
- No abrupt closure while apps are still loading

### Registry Location

Startup entry: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\LoginLight`

This is a **user-level** startup (not system-wide), requiring no administrator privileges.

### Performance

- **Minimal overhead**: Uses native Windows APIs
- **Multi-threaded**: Video playback + CPU monitoring run independently
- **Clean exit**: Properly disposes all resources

---

## Troubleshooting

### Video doesn't play

- Verify `assets\login.mp4` exists
- Check video codec compatibility (MP4 H.264 recommended)
- Test video in Windows Media Player first

### Doesn't start at login

- Run `Install-Startup.ps1` again
- Check registry: `Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`
- Verify PowerShell execution policy allows scripts

### App stays open too long

- Lower `$cpuLowThreshold` (e.g., to 40%)
- Reduce `$initialWaitSeconds` (minimum 3 seconds recommended)

### Multiple windows on single monitor

- This is intentional for multi-monitor setups
- If undesired, modify script to target primary screen only

---

## Advanced Customization

### Use RAM instead of CPU monitoring

Replace `Get-CpuUsage` function:

```powershell
function Get-RamUsage {
  $os = Get-CimInstance Win32_OperatingSystem
  $totalMem = $os.TotalVisibleMemorySize
  $freeMem = $os.FreePhysicalMemory
  return [math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 2)
}
```

Then update thresholds accordingly (RAM patterns differ from CPU).

### Disable looping (always play once and exit)

Set:

```powershell
$cpuHighThreshold = 100  # Never loop
$cpuLowThreshold = 0     # Always exit after first play
```

---

## Requirements

- **OS**: Windows 10/11
- **PowerShell**: 5.1+ (pre-installed on Windows)
- **.NET Framework**: 4.5+ (pre-installed on Windows)

---

## License

Free to use and modify. No warranty provided.

---

## Credits

Created for intelligent Windows startup experience.

**Version**: 1.0  
**Date**: November 2025
