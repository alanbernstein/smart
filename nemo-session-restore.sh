#!/bin/bash
# Restore Nemo windows from saved session file

# Configuration
SAVE_FILE="$HOME/.config/smart-session/nemo-session.txt"

# Check if save file exists
if [ ! -f "$SAVE_FILE" ]; then
    echo "Error: No saved session found at $SAVE_FILE"
    echo "Run nemo-save.sh first to save a session."
    exit 1
fi

# Check if wmctrl is installed
if ! command -v wmctrl &> /dev/null; then
    echo "Error: wmctrl is not installed. Please install it with:"
    echo "  sudo apt install wmctrl"
    exit 1
fi

# Check if nemo is installed
if ! command -v nemo &> /dev/null; then
    echo "Error: nemo is not installed."
    exit 1
fi

echo "Restoring Nemo windows from saved session..."

# Count windows to restore
window_count=$(wc -l < "$SAVE_FILE")
echo "Found $window_count window(s) to restore"

# Read each line (directory path) and open it in Nemo
count=0
while IFS= read -r dir_path; do
    # Skip empty lines
    [[ -z "$dir_path" || "$dir_path" == \#* ]] && continue
    
    count=$((count + 1))
    echo "[$count/$window_count] Opening: $dir_path"
    
    # Try to open the directory
    # Use quotes to handle spaces in paths
    nemo "$dir_path" 2>/dev/null &
    
    # Small delay to avoid overwhelming the system
    sleep 0.3
done < "$SAVE_FILE"

echo "Restored $count Nemo window(s)"