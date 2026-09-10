#!/bin/sh

FOCUSED_CLASS=$(hyprctl activewindow -j | jq -r '.class')

if [ "$FOCUSED_CLASS" = "HeadlessKitty" ]; then
    # kitty tracks which window is focused itself
    # FOCUSED_CLASS is not the actual window and rather the headless kitty instance
    KITTY_WINDOW_ID=$(
        kitty @ --to unix:/tmp/kitty-socket ls |
        jq -r '.[] | .tabs[].windows[] | select(.is_focused == true) | .id'
    )

    exec kitty @ \
        --to unix:/tmp/kitty-socket \
        launch \
        --match "id:$KITTY_WINDOW_ID" \
        --cwd=current \
        --type=os-window
else
    exec kitty @ \
        --to unix:/tmp/kitty-socket \
        launch \
        --type=os-window
fi
