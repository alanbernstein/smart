#!/bin/bash
# Restore windows from JSON session file based on a whitelist of applications

# Configuration
SESSION_FILE="$HOME/.config/window-session.json"
WHITELIST_FILE="$HOME/.window-restore-whitelist.txt"

# Default whitelist (will be created if file doesn't exist)
DEFAULT_WHITELIST="nemo
terminator"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it with:"
    echo "  sudo apt install jq"
    exit 1
fi

# Check if JSON session file exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "Error: Session file not found at $SESSION_FILE"
    echo "Run save-all-windows.sh first to create a session."
    exit 1
fi

# Create default whitelist if it doesn't exist
if [ ! -f "$WHITELIST_FILE" ]; then
    echo "Creating default whitelist at $WHITELIST_FILE"
    echo "$DEFAULT_WHITELIST" > "$WHITELIST_FILE"
    echo "Edit this file to customize which applications to restore."
    echo ""
fi

# Read whitelist into an array, skipping comments and empty lines
whitelist=()
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    # Trim whitespace
    line=$(echo "$line" | xargs)
    whitelist+=("$line")
done < "$WHITELIST_FILE"

echo "Restoring windows from: $SESSION_FILE"
echo "Using whitelist from: $WHITELIST_FILE"
echo ""
echo "Whitelisted applications:"
printf '  - %s\n' "${whitelist[@]}"
echo ""

# Function to check if a process is in the whitelist
is_whitelisted() {
    local process="$1"
    for allowed in "${whitelist[@]}"; do
        [ -z "$allowed" ] && continue
        if [ "$process" = "$allowed" ]; then
            return 0
        fi
    done
    return 1
}

# Function to launch an application
launch_app() {
    local process_name="$1"
    local window_title="$2"
    local cmdline="$3"
    
    echo "Launching: $process_name"
    echo "  Title: $window_title"
    
    # Special handling for different application types
    case "$process_name" in
        nemo)
            # Extract path from Nemo window title
            if [[ "$window_title" == "Home" ]]; then
                nemo "$HOME" &
            elif [[ "$window_title" =~ " - "(/.*) ]]; then
                path="${BASH_REMATCH[1]}"
                nemo "$path" &
            elif [[ "$window_title" == /* ]]; then
                nemo "$window_title" &
            else
                echo "  Warning: Could not parse Nemo path, skipping"
                return
            fi
            ;;
        firefox|chromium|chrome|google-chrome)
            # For browsers, just launch them (they typically restore tabs themselves)
            if command -v "$process_name" &> /dev/null; then
                "$process_name" &
            else
                echo "  Warning: $process_name not found in PATH"
            fi
            ;;
        code)
            # VS Code - try to extract directory from cmdline
            if [[ "$cmdline" =~ /usr/bin/code[[:space:]]+(.+) ]]; then
                workspace="${BASH_REMATCH[1]}"
                code "$workspace" &
            else
                code &
            fi
            ;;
        gnome-terminal|terminal)
            # Terminal - just launch it
            if command -v gnome-terminal &> /dev/null; then
                gnome-terminal &
            elif command -v terminal &> /dev/null; then
                terminal &
            fi
            ;;
        gedit|gnome-text-editor)
            # Text editors - just launch
            if command -v "$process_name" &> /dev/null; then
                "$process_name" &
            fi
            ;;
        *)
            # Generic case - try to run the command line
            if [ -n "$cmdline" ] && [ "$cmdline" != "unknown" ]; then
                echo "  Using cmdline: $cmdline"
                eval "$cmdline" &
            elif command -v "$process_name" &> /dev/null; then
                "$process_name" &
            else
                echo "  Warning: Don't know how to launch $process_name"
            fi
            ;;
    esac
}

# Parse JSON and restore windows
restored_count=0
skipped_count=0

# Get the total number of windows
total_windows=$(jq 'length' "$SESSION_FILE")

echo "Found $total_windows window(s) in session file"
echo ""

# Iterate through each window in the JSON
for i in $(seq 0 $((total_windows - 1))); do
    # Extract fields using jq
    process_name=$(jq -r ".[$i].process_name" "$SESSION_FILE")
    window_title=$(jq -r ".[$i].window_title" "$SESSION_FILE")
    cmdline=$(jq -r ".[$i].cmdline" "$SESSION_FILE")
    
    # Check if process is whitelisted
    if is_whitelisted "$process_name"; then
        echo "[$((restored_count + 1))] $process_name"
        launch_app "$process_name" "$window_title" "$cmdline"
        restored_count=$((restored_count + 1))
        
        # Small delay to avoid overwhelming the system
        sleep 0.5
    else
        skipped_count=$((skipped_count + 1))
    fi
done

echo ""
echo "Restoration complete!"
echo "  Restored: $restored_count window(s)"
echo "  Skipped: $skipped_count window(s) (not in whitelist)"
echo ""
echo "To customize which apps are restored, edit: $WHITELIST_FILE"