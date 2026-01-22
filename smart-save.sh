#!/bin/bash
# Save all open windows with their process names and titles

# Configuration
SESSION_DIR="$HOME/.config/smart-session"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SAVE_FILE="$SESSION_DIR/window-session-${TIMESTAMP}.json"
SYMLINK_FILE="$SESSION_DIR/window-session.json"
TEMP_FILE="$SESSION_DIR/window-session.json.tmp"

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

# Set DISPLAY and XAUTHORITY for cronjob compatibility
if [ -z "$DISPLAY" ]; then
    export DISPLAY="$SMART_DISPLAY"
fi

# Find and set XAUTHORITY if not already set (needed for cron jobs)
if [ -z "$XAUTHORITY" ]; then
    # Try common locations for X authority file
    for auth_file in "/run/user/$(id -u)/gdm/Xauthority" \
                     "/run/user/$(id -u)/.mutter-Xwaylandauth."* \
                     "$HOME/.Xauthority"; do
        if [ -f "$auth_file" ]; then
            export XAUTHORITY="$auth_file"
            break
        fi
    done
fi

echo "Saving all window states to JSON..."

# Create temporary file for JSON entries
> "$TEMP_FILE"

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
    
    # Escape quotes and backslashes in strings for JSON
    window_title_escaped=$(echo "$window_title" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    window_class_escaped=$(echo "$window_class" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    process_name_escaped=$(echo "$process_name" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    cmdline_escaped=$(echo "$cmdline" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    # Write JSON object to temp file
    echo "  {" >> "$TEMP_FILE"
    echo "    \"window_id\": \"$window_id\"," >> "$TEMP_FILE"
    echo "    \"desktop\": $desktop," >> "$TEMP_FILE"
    echo "    \"pid\": $pid," >> "$TEMP_FILE"
    echo "    \"process_name\": \"$process_name_escaped\"," >> "$TEMP_FILE"
    echo "    \"window_class\": \"$window_class_escaped\"," >> "$TEMP_FILE"
    echo "    \"window_title\": \"$window_title_escaped\"," >> "$TEMP_FILE"
    echo "    \"cmdline\": \"$cmdline_escaped\"" >> "$TEMP_FILE"
    echo "  }," >> "$TEMP_FILE"
done

# Now build the final JSON file
echo "[" > "$SAVE_FILE"

# Add all entries from temp file, removing the trailing comma from the last entry
if [ -s "$TEMP_FILE" ]; then
    # Remove the last comma
    sed '$ s/,$//' "$TEMP_FILE" >> "$SAVE_FILE"
fi

# Close JSON array
echo "]" >> "$SAVE_FILE"

# Clean up temp file
rm -f "$TEMP_FILE"

# Count windows saved
window_count=$(grep -c '"window_id"' "$SAVE_FILE")

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
echo "  jq . $SYMLINK_FILE  # if you have jq installed for pretty printing"