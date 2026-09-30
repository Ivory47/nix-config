{ pkgs, ... }:

{

    imports = [
        ./kitty
    ];

    home.packages = with pkgs; [
        awww

        mako # notification service
        inkscape

        nautilus # file explorer

        # fonts 
        nerd-fonts.caskaydia-cove
        font-awesome
    ];


    # default apps 
    xdg.mimeApps = {
        enable = true;
        defaultApplications = {
            "text/html" = "firefox.desktop";
            "x-scheme-handler/http" = "firefox.desktop";
            "x-scheme-handler/https" = "firefox.desktop";
            "x-scheme-handler/about" = "firefox.desktop";
            "x-scheme-handler/unknown" = "firefox.desktop";

            # Image files
            "image/jpeg" = "firefox.desktop";
            "image/png" = "firefox.desktop";
            "image/gif" = "firefox.desktop";
            "image/webp" = "firefox.desktop";
            "image/svg+xml" = "firefox.desktop";
            "image/bmp" = "firefox.desktop";
            "image/tiff" = "firefox.desktop";
            "image/x-icon" = "firefox.desktop";
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
}
