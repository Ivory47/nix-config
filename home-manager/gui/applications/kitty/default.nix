{ ... }:

{
    programs.kitty = {
        enable = true;

        settings = {
            font_size = 10;
            background_opacity = 0.73;
            confirm_os_window_close = 0;
            window_padding_width = "3 6";
            allow_remote_control = true;
        };

        extraConfig = ''
            include ~/.config/kitty/colors.conf
        '';
    };
    xdg.configFile."scripts/open-kitty.sh" = {
        source = ../../../scripts/open-kitty.sh;
        executable = true;
    };
}
