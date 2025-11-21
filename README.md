# LoginLight 🎬

**Intelligent startup splash screen for Windows** - Full-screen video display with CPU-aware adaptive looping.

## Features

✅ **Auto-start at Windows login** (fastest possible startup)  
✅ **Full-screen on all monitors** (multi-display support)  
✅ **CPU-aware intelligent looping** (adapts to system load)  
✅ **Smooth fade-out transition** (professional exit)  
✅ **Native PowerShell + WPF** (no external dependencies)  
✅ **One-line installer** (downloads everything automatically)

---

## Quick Install

**Copy and paste this command in PowerShell (Admin not required):**

```powershell
irm https://raw.githubusercontent.com/LightZirconite/LoginLight/main/Install-Startup.ps1 | iex
```

✅ Downloads `LoginSplash.ps1` and `login.mp4` from GitHub  
✅ Installs to `%LOCALAPPDATA%\LoginLight\`  
✅ Registers to Windows Startup folder  
✅ Ready on next login!

---

## How It Works

1. **Startup**: Launches automatically when you log into Windows
2. **Display**: Shows `login.mp4` full-screen on all monitors
3. **Initial wait**: Plays for 3 seconds minimum
4. **CPU monitoring**: 
   - If CPU ≥ 80% → **loops video** (system busy with startup tasks)
   - If CPU ≤ 50% → **prepares to exit** (system ready)
5. **Safety**: Auto-exits after 60 seconds if system remains busy
6. **Exit**: Waits for video to complete, then fades out smoothly

---

## Manual Installation

### 1. Download & Install

Right-click `Install-Startup.ps1` → **Run with PowerShell**

This automatically downloads all files from GitHub and sets up startup.

### 2. Test

Log out and log back in to see it at startup, or test manually:

```powershell
& "$env:LOCALAPPDATA\LoginLight\LoginSplash.ps1"
```

---

## Uninstallation

**One-line uninstaller:**

```powershell
irm https://raw.githubusercontent.com/LightZirconite/LoginLight/main/Uninstall-Startup.ps1 | iex
```

Or download and run `Uninstall-Startup.ps1` manually.

This removes the startup shortcut and deletes all installed files from `%LOCALAPPDATA%\LoginLight\`.

---

## Configuration

Edit `LoginSplash.ps1` in `%LOCALAPPDATA%\LoginLight\` to customize:

```powershell
$initialWaitSeconds = 3            # Minimum display time
$cpuHighThreshold = 80             # CPU % to keep looping
$cpuLowThreshold = 50              # CPU % to allow exit
$cpuCheckIntervalMs = 1000         # CPU check frequency (ms)
$fadeOutDurationSeconds = 1.5      # Fade-out animation duration
$maxTimeoutSeconds = 60            # Safety timeout (force exit)
```

---

## Technical Details

### Why CPU Monitoring?

At Windows startup, many background services and applications load simultaneously, causing CPU spikes. This app intelligently waits for the system to stabilize before closing, ensuring:

- User sees the splash screen during the "busy" startup phase
- Smooth transition to desktop when system is ready
- No abrupt closure while apps are still loading

### Installation Location

- **Files**: `%LOCALAPPDATA%\LoginLight\` (e.g., `C:\Users\YourName\AppData\Local\LoginLight\`)
- **Startup**: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\LoginLight.lnk`

This is a **user-level** installation (not system-wide), requiring no administrator privileges.

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
