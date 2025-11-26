#!/bin/bash
# Save current Nemo window directories to a file

# Configuration
SESSION_DIR="$HOME/.config/smart-session"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SAVE_FILE="$SESSION_DIR/nemo-session-${TIMESTAMP}.txt"
SYMLINK_FILE="$SESSION_DIR/nemo-session.txt"

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

echo "Saving Nemo window states..."

# Clear the save file
> "$SAVE_FILE"

# Get all Nemo windows
# wmctrl -lx shows: <window_id> <desktop> <window_class> <client_machine> <window_title>
# We filter for nemo windows and extract paths
wmctrl -lx | grep -i "nemo.Nemo" | while IFS= read -r line; do
    # Get the window title (everything after the 4th field)
    window_title=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    # Skip if empty
    [ -z "$window_title" ] && continue
    
    # Check if title is exactly "Home"
    if [[ "$window_title" == "Home" ]]; then
        echo "$HOME" >> "$SAVE_FILE"
    # If title contains " - /", extract everything after the " - "
    elif [[ "$window_title" =~ " - "(/.*) ]]; then
        path="${BASH_REMATCH[1]}"
        echo "$path" >> "$SAVE_FILE"
    # If title starts with /, it's a full path
    elif [[ "$window_title" == /* ]]; then
        echo "$window_title" >> "$SAVE_FILE"
    else
        # For anything else that couldn't be parsed, save as a comment
        echo "# Unable to parse: $window_title" >> "$SAVE_FILE"
    fi
done

# Count how many windows were saved
window_count=$(grep -c . "$SAVE_FILE" 2>/dev/null || echo 0)

if [ "$window_count" -eq 0 ]; then
    echo "No Nemo windows found."
    rm -f "$SAVE_FILE"
    exit 1
else
    # Create symlink to latest file
    ln -sf "$(basename "$SAVE_FILE")" "$SYMLINK_FILE"

    echo "Saved $window_count Nemo window(s) to $SAVE_FILE"
    echo "Symlink updated: $SYMLINK_FILE -> $(basename "$SAVE_FILE")"
    echo ""
    echo "Saved directories:"
    cat -n "$SAVE_FILE"
    echo ""
    echo "NOTE: If paths don't look right, you can manually edit $SAVE_FILE"
fi
