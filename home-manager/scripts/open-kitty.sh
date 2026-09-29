#!/bin/sh

# kitty tracks which window is focused itself
# FOCUSED_CLASS is not the actual window and rather the headless kitty instance
FOCUSED_CLASS=$(hyprctl activewindow -j | jq -r '.class')

if [ "$FOCUSED_CLASS" = "HeadlessKitty" ]; then
    # Fetch window data once
    WINDOW_DATA=$(kitty @ --to unix:/tmp/kitty-socket ls | jq -r '.[] | .tabs[].windows[] | select(.is_focused == true)')

    KITTY_WINDOW_ID=$(echo "$WINDOW_DATA" | jq -r '.id')
    
    # 1. Check if the top process is SSH
    if echo "$WINDOW_DATA" | jq -r '.foreground_processes[].cmdline[]' 2>/dev/null | grep -qE "ssh|kitten"; then
        
        # 2. Extract the exact binary and arguments as separate lines, then map them to the launch command
        # This prevents quotes from breaking or the window from closing immediately
        exec kitty @ --to unix:/tmp/kitty-socket ls | \
        jq -r '.[] | .tabs[].windows[] | select(.is_focused == true) | .foreground_processes[0].cmdline[]' | \
        xargs kitty @ \
            --to unix:/tmp/kitty-socket \
            launch \
            --match "id:$KITTY_WINDOW_ID" \
            --type=os-window
            
    else
        # Open in the current local directory if it's a standard shell
        exec kitty @ \
            --to unix:/tmp/kitty-socket \
            launch \
            --match "id:$KITTY_WINDOW_ID" \
            --cwd=current \
            --type=os-window
    fi
else
    exec kitty @ \
        --to unix:/tmp/kitty-socket \
        launch \
        --type=os-window
fi
