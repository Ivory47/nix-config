
# persistent recent directories, shared by all shells and kept across restarts
autoload -Uz add-zsh-hook chpwd_recent_dirs chpwd_recent_filehandler
add-zsh-hook chpwd chpwd_recent_dirs
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
zstyle ':chpwd:*' recent-dirs-file "${XDG_STATE_HOME:-$HOME/.local/state}/zsh/recent-dirs"
zstyle ':chpwd:*' recent-dirs-max 100
zstyle ':chpwd:*' recent-dirs-prune 'pattern:/nix/store(|/*)'

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
    local reply dir
    # loads the shared recent-dirs file into $reply, newest first, full paths
    chpwd_recent_filehandler
    local selected=$(
        for dir in $reply; do
            # show with ~, skip deleted dirs and the current dir
            [[ $dir != $PWD && -d $dir ]] && print -r -- "${(D)dir}"
        done | fzf --no-sort --height 40% --prompt="📂 Last directories> "
    )

    if [ -n "$selected" ]; then
        selected=$(sed "s|^~|$HOME|" <<< "$selected")
        z "$selected"
    fi
    zle reset-prompt
}

# register function
zle -N fzf_history_widget
zle -N fzf_zoxide_widget

# bind
bindkey "^L" fzf_history_widget # last command
bindkey "^P" fzf_zoxide_widget # paths

