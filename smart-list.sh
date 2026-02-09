#!/bin/bash
# List what would be restored from the saved session (dry-run of smart-restore)

# Configuration
SESSION_FILE="$HOME/.config/smart-session/window-session.json"
WHITELIST_FILE="$HOME/.config/smart-session/window-restore-whitelist.txt"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it with:"
    echo "  sudo apt install jq"
    exit 1
fi

# Check if JSON session file exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "Error: Session file not found at $SESSION_FILE"
    echo "Run smart-save.sh first to create a session."
    exit 1
fi

# Show which session file we're reading (resolve symlink)
real_file=$(readlink -f "$SESSION_FILE")
echo "Session file: $SESSION_FILE"
if [ "$real_file" != "$SESSION_FILE" ]; then
    echo "  -> $(basename "$real_file")"
fi
echo ""

# Check if whitelist file exists
if [ ! -f "$WHITELIST_FILE" ]; then
    echo "Error: Whitelist file not found at $WHITELIST_FILE"
    echo "Run smart-restore.sh first to create a default whitelist."
    exit 1
fi

# Read whitelist into an array, skipping comments and empty lines
whitelist=()
while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] && continue
    line=$(echo "$line" | xargs)
    whitelist+=("$line")
done < "$WHITELIST_FILE"

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

# Sort windows by process name, then window title
sorted_json=$(jq 'sort_by(.process_name, .window_title)' "$SESSION_FILE")
total_windows=$(echo "$sorted_json" | jq 'length')

# Parse sorted JSON and list windows
restore_count=0
skip_count=0

echo "=== Would restore ==="
echo ""

for i in $(seq 0 $((total_windows - 1))); do
    process_name=$(echo "$sorted_json" | jq -r ".[$i].process_name")
    window_title=$(echo "$sorted_json" | jq -r ".[$i].window_title")

    if is_whitelisted "$process_name"; then
        restore_count=$((restore_count + 1))
        printf "  [%d] %-20s %s\n" "$restore_count" "$process_name" "$window_title"
    else
        skip_count=$((skip_count + 1))
    fi
done

if [ "$restore_count" -eq 0 ]; then
    echo "  (none)"
fi

echo ""
echo "=== Would skip ==="
echo ""

skip_num=0
for i in $(seq 0 $((total_windows - 1))); do
    process_name=$(echo "$sorted_json" | jq -r ".[$i].process_name")
    window_title=$(echo "$sorted_json" | jq -r ".[$i].window_title")

    if ! is_whitelisted "$process_name"; then
        skip_num=$((skip_num + 1))
        printf "  [%d] %-20s %s\n" "$skip_num" "$process_name" "$window_title"
    fi
done

if [ "$skip_num" -eq 0 ]; then
    echo "  (none)"
fi

echo ""
echo "Summary: $restore_count to restore, $skip_count to skip (out of $total_windows total)"
