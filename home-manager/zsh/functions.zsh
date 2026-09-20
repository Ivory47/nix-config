excludes=(
    ".git"
    ".local"
    ".cache"
    ".steam"
	".mydotfiles"
)

# Convert the array into multiple --exclude flags dynamically
exclude_flags=()
for item in "${excludes[@]}"; do
    exclude_flags+=(--exclude "$item")
done


function f() {
	local selected_path
	selected_path=$(fd -L --hidden "${exclude_flags[@]}" . "${1:-.}" | sed "s|^$HOME|~|" | fzf)
	selected_path=${selected_path/#\~/$HOME}
	[[ -z "$selected_path" ]] && return 0

	# If the user selected a directory, navigate to it immediately
	if [[ -d "$selected_path" ]]; then
		print -s "cd $selected_path"
		z "$selected_path" || return 1
	elif [[ -f "$selected_path" ]]; then
		# 1. Seamlessly follow any symlink chains to get the real target path
		local real_target
		real_target=$(readlink -f "$selected_path")

		# 2. Extract the mime-type of the actual destination file
		local mime
		mime=$(file --mime-type -b "$real_target")

		# 3. Match against allowed plain text, shell script, or empty file categories
		if [[ "$mime" =~ ^text/ || "$mime" == "application/x-shellscript" || "$mime" == "inode/x-empty" ]]; then
			# Add cd <dir> to history 
			print -s "cd $(dirname "$selected_path")"
			# Add nvim <file> to history 
			print -s "nvim ${(q)selected_path:t}"

			# 4. Jump to the folder where the link sits, but open the real target
			z "$(dirname "$selected_path")" || return 1
			nvim "$real_target" || return 1
		else
			# If it's a binary payload (e.g. PNG), just move to its folder location
			z "$(dirname "$selected_path")" || return 1
		fi
	fi
}

function icats() {
	local file
	# Find images in the current directory using fd and preview them with kitty icat
	file=$(fd --max-depth 1 --type file --extension png --extension jpg --extension jpeg --extension gif --extension webp | \
		fzf --preview 'kitty +kitten icat --clear --transfer-mode=memory --stdin=no --place="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0" {}' \
		--preview-window=right:60%)

	kitty +kitten icat --clear

	# Open the selected file with icat if a choice was made
	if [[ -n "$file" ]]; then
		icat "$file"
	fi
}


function rebuild() {
    if [[ "$NIX_CONFIG_TYPE" == "desktop" || "$NIX_CONFIG_TYPE" == "laptop" ]]; then
        echo "Rebuilding $NIX_CONFIG_TYPE-Config..."
        sudo nixos-rebuild switch --impure --flake "/etc/nixos#$NIX_CONFIG_TYPE"
    else
        echo "Warning: unknown NIX_CONFIG_TYPE (current: '$NIX_CONFIG_TYPE')."
        echo "Rebuilding default-Config..."
        sudo nixos-rebuild switch --impure --flake "/etc/nixos#default"
    fi
}
