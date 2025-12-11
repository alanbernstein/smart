# SMART: Session Manager and Restore Tool

Simple scripts to save and restore window sessions on Ubuntu. Motivated by using Nemo, a great file manager, without the Cinnamon backend which is required for saving sessions. **Requires X11** (not Wayland).

## Setup

Verify that you're using X11:

```bash
echo $XDG_SESSION_TYPE  # should show x11, not wayland
```

Install required tools:
```bash
sudo apt install wmctrl jq
```

- **wmctrl**: Required for querying X11 window information
- **jq**: Required for JSON processing

Create an app restore whitelist (plain text file with one app name per line):
```bash
# The script creates a default whitelist on first run
./smart-restore.sh

# Or manually create your whitelist
cat > ~/.config/smart-session/window-restore-whitelist.txt << EOF
nemo
terminator
EOF
```

## Usage

```bash
# 1. Save your current session
./smart-save.sh

# 2. Later, restore whitelisted windows
./smart-restore.sh
```

## Crontab

Auto-saving is crucial for recovering window contents from a crash, so run smart-save.sh automatically with cron. The scripts set DISPLAY=":0" for compatibility with the cron environment; you may need to adjust this for your usage.

```bash
crontab -e
# Save every 6 hours
0 */6 * * * /usr/local/bin/smart-save.sh
```

## Script details

### smart-save.sh

Saves all open window information to `~/.config/smart-session/` in JSON format.

**Features:**
- Timestamped session files (e.g., `window-session-20251205-143025.json`)
- Symlink to latest session (`window-session.json`)
- Empty sessions don't update the symlink (crash protection)
- Cronjob compatible (sets DISPLAY automatically)

**Usage:**
```bash
./smart-save.sh
```

**Output:**
- Session file: `~/.config/smart-session/window-session-YYYYMMDD-HHMMSS.json`
- Symlink: `~/.config/smart-session/window-session.json` → latest non-empty session

**JSON format:**
```json
[
  {
    "window_id": "0x03200003",
    "desktop": 0,
    "pid": 12345,
    "process_name": "nemo",
    "window_class": "nemo.Nemo",
    "window_title": "Downloads - /home/user/Downloads",
    "cmdline": "/usr/bin/nemo /home/user/Downloads"
  },
  ...
]
```

### smart-restore.sh

Restores windows from the latest JSON session file based on a whitelist of applications.

**Features:**
- Whitelist-based restoration (only restores approved apps)
- Delay between launches to avoid overwhelming the system
- Special handling for
  - Nemo: opens windows to same directories (only one tab per window)
  - Terminator: opens windows to same directories (only one tab/frame per window)
