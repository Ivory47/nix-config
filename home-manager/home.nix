{ config, pkgs, inputs, ... }:

{
    home.username = "user";
    home.homeDirectory = "/home/user";

    home.packages = with pkgs; [
        gtrash
        fzf
        fd
        file
        tree
        jq
        lazygit
        wl-clipboard
        inputs.hyprmod.packages.${pkgs.stdenv.hostPlatform.system}.default
        fastfetch
        brightnessctl
        awww
        inputs.matugen.packages.${system}.default

        mako # notification service

        nautilus

        quickshell


        # fonts 
        nerd-fonts.caskaydia-cove
        font-awesome
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

    # terminal
    programs.zsh = {
        enable = true;

        sessionVariables = {
            FZF_DEFAULT_OPTS = "--height 40% --reverse";
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
            hms = "home-manager switch --flake ~/.config/home-manager -b backup && source ~/.zshrc";
            qsr = "~/.config/home-manager/quickshell/reload.sh";
        };

        initContent = ''
            
            zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

            source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
            source ${./zsh/functions.zsh}
            source ${./zsh/widgets.zsh}
        '';
    };

    programs.kitty = {
        enable = true;

        settings = {
            font_size = 10;
            background_opacity = 0.7;
            confirm_os_window_close = 0;
            window_padding_width = "3 6";
            allow_remote_control = true;
        };

        extraConfig = ''
            include ~/.config/kitty/colors.conf
        '';
    };
    xdg.configFile."scripts/open-kitty.sh" = {
        source = ./scripts/open-kitty.sh;
        executable = true;
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

    # force is required cause hyprmod deletes the symlink :/
    xdg.configFile."hypr/hyprland.lua" = {
        source = ./hypr/hyprland.lua;
        force = true;
    };

    gtk = {
        enable = true;

        iconTheme = {
            package = pkgs.papirus-icon-theme;
            name = "Papirus-Dark";
        };
    };

    home.pointerCursor = {
        enable = true;

        # package = pkgs.bibata-cursors;
        # name = "Bibata-Modern-Classic";
        package = pkgs.gnome-themes-extra;
        name = "Adwaita";
        size = 24;

        gtk.enable = true;
        hyprcursor.enable = true;
    };

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

    # colours matching wallpaper
    xdg.configFile."matugen/config.toml".source = ./matugen/config.toml;

    xdg.configFile."matugen/templates/colors.conf".source = ./matugen/templates/colors.conf;

    
    xdg.configFile."matugen/templates/hyprland.lua".source = ./matugen/templates/hyprland.lua;

    xdg.configFile."matugen/templates/kitty.conf".source = ./matugen/templates/kitty.conf;

    # fastfetch 
    xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;

    # quickshell
    xdg.configFile."quickshell/status-bar".source = ./quickshell/status-bar;

    # normal programs
    programs.firefox = {
        enable = true;

        profiles.main = {
            isDefault = true;

            settings = {
                # Dark Firefox UI
                "extensions.autoDisableScopes" = 0;
                # Dark websites
                "layout.css.prefers-color-scheme.content-override" = 0;
            };

            extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
                bitwarden
                ublock-origin
                sponsorblock
            ];
        };
    };

    programs.chromium = {
        enable = true;

        package = pkgs.vivaldi.override {
            proprietaryCodecs = true;
            enableWidevine = true;
        };

        extensions = [
            # Bitwarden
            { id = "nngceckbapebfimnlniiiahkandclblb"; }

            # uBlock Origin Lite
            { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; }

            # SponsorBlock
            { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; }
        ];
    };

    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
}
