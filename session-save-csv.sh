#!/bin/bash
# Save all open windows with their process names and titles in CSV format

# Configuration
SESSION_DIR="$HOME/.config/smart-session"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SAVE_FILE="$SESSION_DIR/window-session-${TIMESTAMP}.csv"
SYMLINK_FILE="$SESSION_DIR/window-session.csv"

# Create session directory if it doesn't exist
mkdir -p "$SESSION_DIR"

# For multi-display setups, set SMART_DISPLAY in your environment or crontab
# Example: export SMART_DISPLAY=:1
: ${SMART_DISPLAY:=:0}

# Check if wmctrl is installed
if ! command -v wmctrl &> /dev/null; then
    echo "Error: wmctrl is not installed. Please install it with:"
    echo "  sudo apt install wmctrl"
    exit 1
fi

# Set DISPLAY for cronjob compatibility
if [ -z "$DISPLAY" ]; then
    export DISPLAY="$SMART_DISPLAY"
fi

echo "Saving all window states to CSV..."

# Write CSV header
echo "window_id,desktop,pid,process_name,window_class,window_title,cmdline" > "$SAVE_FILE"

# Get all windows with extended information
# wmctrl -lxp shows: <window_id> <desktop> <PID> <window_class> <client_machine> <window_title>
wmctrl -lxp | while IFS= read -r line; do
    # Parse the line
    window_id=$(echo "$line" | awk '{print $1}')
    desktop=$(echo "$line" | awk '{print $2}')
    pid=$(echo "$line" | awk '{print $3}')
    window_class=$(echo "$line" | awk '{print $4}')
    
    # Get the window title (everything after the 5th field)
    window_title=$(echo "$line" | awk '{for(i=6;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    # Get the process name from the PID
    if [ -d "/proc/$pid" ]; then
        process_name=$(cat /proc/$pid/comm 2>/dev/null || echo "unknown")
    else
        process_name="unknown"
    fi
    
    # Get the full command line (useful for some apps)
    if [ -d "/proc/$pid" ]; then
        cmdline=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' | sed 's/[[:space:]]*$//')
        # If cmdline is empty, use comm
        [ -z "$cmdline" ] && cmdline="$process_name"
    else
        cmdline="$process_name"
    fi
    
    # Escape quotes for CSV (double them) and wrap fields in quotes
    window_title_csv=$(echo "$window_title" | sed 's/"/""/g')
    window_class_csv=$(echo "$window_class" | sed 's/"/""/g')
    process_name_csv=$(echo "$process_name" | sed 's/"/""/g')
    cmdline_csv=$(echo "$cmdline" | sed 's/"/""/g')
    
    # Write CSV row (all fields quoted to handle commas and special chars)
    echo "\"$window_id\",$desktop,$pid,\"$process_name_csv\",\"$window_class_csv\",\"$window_title_csv\",\"$cmdline_csv\"" >> "$SAVE_FILE"
done

# Count windows saved (subtract 1 for header)
window_count=$(($(wc -l < "$SAVE_FILE") - 1))

# Only update symlink if we saved at least one window
if [ "$window_count" -gt 0 ]; then
    ln -sf "$(basename "$SAVE_FILE")" "$SYMLINK_FILE"
    echo "Saved $window_count window(s) to $SAVE_FILE"
    echo "Symlink updated: $SYMLINK_FILE -> $(basename "$SAVE_FILE")"
else
    echo "Saved $window_count window(s) to $SAVE_FILE"
    echo "Symlink NOT updated (empty session)"
fi
echo ""
echo "You can view the file with:"
echo "  cat $SYMLINK_FILE"
echo "  column -t -s, $SYMLINK_FILE  # formatted view"
echo "  libreoffice $SYMLINK_FILE    # open in spreadsheet"