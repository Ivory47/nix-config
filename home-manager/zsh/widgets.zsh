
fzf_history_widget() {
    # -n <number> outputs all commands since command <number>
    # importantly it removes the numbers from the output as well
    local selected=$(history -n 1 | tac | awk '!seen[$0]++' | fzf --no-sort --height 40%)
    if [ -n "$selected" ]; then
        # everything left of the cursor is stored in LBUFFER
        LBUFFER+="$selected"
    fi
    # redraws the prompt
    zle reset-prompt
}

fzf_zoxide_widget() {
    local selected=$(dirs -p | awk '!seen[$0]++' | fzf --nth=-1 --height 40% --prompt="📂 Last directories> ")


    if [ -n "$selected" ]; then
        selected=$(sed "s|^~|$HOME|" <<< "$selected")
        z "$selected"
        zle reset-prompt
    fi
}

# register function
zle -N fzf_history_widget
zle -N fzf_zoxide_widget

# bind
bindkey "^L" fzf_history_widget # last command
bindkey "^P" fzf_zoxide_widget # paths

