{ config, pkgs, inputs, ... }:

{
    imports = [
        inputs.silentSDDM.nixosModules.default
    ];

    hardware.bluetooth.enable = true;

    security.rtkit.enable = true;

    services.pipewire = {
        enable = true;

        alsa.enable = true;
        alsa.support32Bit = true;

        pulse.enable = true;
    };

    services.printing = {
        enable = true;
        # potentially deprecated
        drivers = with pkgs; [
            cups-filters
            cups-browsed
        ];
    };


    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
        kitty
        gnome-themes-extra
    ];

    programs.hyprland = {
        enable = true;
        withUWSM = true;
    };

    services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
    };

    programs.silentSDDM = {
        enable = true;
        theme = "default";

        settings = {
            "General" = {
                scale = 1.3;
            };

            "LockScreen.Message" = {
                font-size = 14;
                icon-size = 20;
            };

            "LoginScreen.MenuArea.Buttons" = {
                size = 42;
            };

            "LoginScreen.MenuArea.Session" = {
                font-size = 14;
                icon-size = 20;
            };

            "LoginScreen.MenuArea.Keyboard" = {
                icon-size = 20;
            };

            "LoginScreen.MenuArea.Power" = {
                icon-size = 20;
            };
        };
    };

    qt.enable = true;

    # programs.regreet = {
    #     enable = true;
    #
    #     theme = {
    #         name = "Adwaita-dark";
    #         package = pkgs.gnome-themes-extra; 
    #     };
    # };

    # not sure if still necessary cause programs.hyprland = { should already do that
    services.displayManager.sessionPackages = [ pkgs.hyprland ];

    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;

    environment.variables = {
        XCURSOR_THEME = "Adwaita";
        XCURSOR_SIZE = "24";
    };

}
