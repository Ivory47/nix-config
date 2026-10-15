{ pkgs, ... }:

{

    imports = [
        ./kitty
    ];

    home.packages = with pkgs; [
        awww

        mako # notification service
        inkscape

        nautilus    # file explorer
        signal-desktop
        mpv

        (texlive.combine {
             inherit (texlive) scheme-full;
        })

        # fonts 
        nerd-fonts.caskaydia-cove
        font-awesome
    ];


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


    # default apps 
    xdg.mimeApps = {
        enable = true;
        defaultApplications = {
            "text/html" = "firefox.desktop";
            "x-scheme-handler/http" = "firefox.desktop";
            "x-scheme-handler/https" = "firefox.desktop";
            "x-scheme-handler/about" = "firefox.desktop";
            "x-scheme-handler/unknown" = "firefox.desktop";

            "application/pdf" = [ "org.pwmt.zathura.desktop" ];

            # Image files
            "image/jpeg" = "firefox.desktop";
            "image/png" = "firefox.desktop";
            "image/gif" = "firefox.desktop";
            "image/webp" = "firefox.desktop";
            "image/svg+xml" = "firefox.desktop";
            "image/bmp" = "firefox.desktop";
            "image/tiff" = "firefox.desktop";
            "image/x-icon" = "firefox.desktop";

            # Video files
            "video/mp4" = [ "mpv.desktop" ];
            "video/x-matroska" = [ "mpv.desktop" ];
            "video/webm" = [ "mpv.desktop" ];
            "video/ogg" = [ "mpv.desktop" ];
            "video/quicktime" = [ "mpv.desktop" ];
            "video/x-msvideo" = [ "mpv.desktop" ];
            "video/x-flv" = [ "mpv.desktop" ];
        };

        associations.added = {
            "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        };
    };

    dconf.settings = {
        "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
        };
    };


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

    programs.zathura = {
        enable = true;

        options = {
            recolor = true;
            recolor-lightcolor = "#1e1e1f";
            recolor-darkcolor = "#cccccc";
            recolor-keephue = true;

            default-bg = "#101011";
            default-fg = "#cccccc";

            # the bar at the bottom
            statusbar-bg = "#1e1e2a";
            statusbar-fg = "#cccccc";

            inputbar-bg = "#1e1e2e";
            inputbar-fg = "#cccccc";
        };
    };
}
