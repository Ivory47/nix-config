{ config, pkgs, inputs, ... }:

{
    home.username = "user";
    home.homeDirectory = "/home/user";

    home.packages = with pkgs; [
        gtrash
        fzf
        fd
        file
        jq
        ripgrep
        lazygit
        fastfetch
        ghostty

    ];

    systemd.user.timers."gtrash-prune" = {
        Timer = {
            OnBootSec = "5m";
            OnUnitActiveSec = "1d";
            Unit = "gtrash-prune.service";
        };

        Install = {
            WantedBy = [ "timers.target" ];
        };
    };

    systemd.user.services."gtrash-prune" = {
        Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.gtrash}/bin/gtrash prune --day 30";
        };
    };

    xdg.enable = true;

    # terminal
    programs.zsh = {
        enable = true;

        sessionVariables = {
            FZF_DEFAULT_OPTS = "--height 40% --reverse";
            EDITOR="nvim";
            VISUAL="nvim";
            SUDO_EDITOR="nvim";
        };

        oh-my-zsh = {
            enable = true;
            plugins = [
                "sudo"
            ];
        };

        autosuggestion = {
            enable = true;
            strategy = [ 
                "completion"
                "history"
            ];
            highlight = "fg=242";
        };

        shellAliases = {
            rm = "gtrash put";
            la = "ls -lAh";
            cd = "z";
            fa = "f ~";
            ssh = "kitty +kitten ssh";
            icat = "kitty +kitten icat";
            nixconf = "sudo -E nvim /etc/nixos/common/configuration.nix";
            # rebuild = "sudo nixos-rebuild switch";
            hconf = "nvim ~/.config/home-manager/home.nix";
            lg = "lazygit";
            hms = "_home-manager-switch && source ~/.config/zsh/.zshrc";
            qsr = "~/.config/home-manager/gui/quickshell/reload.sh";
        };

        initContent = ''
            [[ -d ~/.cache/zsh ]] || mkdir -p ~/.cache/zsh
            export ZSH_COMPDUMP="$HOME/.cache/zsh/zcompdump-$HOST-$ZSH_VERSION"
            
            zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

            source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
            source ${./zsh/functions.zsh}
            source ${./zsh/widgets.zsh}
        '';
    };

    programs.zoxide = {
        enable = true;
        enableZshIntegration = true;
    };

    programs.starship = {
        enable = true;
    };

    programs.neovim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
            (nvim-treesitter.withPlugins (plugins: with plugins; [
                  tree-sitter-nix
                  tree-sitter-lua
                  tree-sitter-bash
                  tree-sitter-json
            ]))
        ];
    };
    xdg.configFile."nvim/init.lua".source = ./nvim/init.lua;

    xdg.userDirs = {
        enable = true;
        createDirectories = true;

        documents = "${config.home.homeDirectory}/Documents";
        download = "${config.home.homeDirectory}/Downloads";
        music = "${config.home.homeDirectory}/Music";
        pictures = "${config.home.homeDirectory}/Pictures";
        videos = "${config.home.homeDirectory}/Videos";

        desktop = null;
        publicShare = null;
        templates = null;
        projects = null;
    };

    # fastfetch 
    xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;


    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
}
