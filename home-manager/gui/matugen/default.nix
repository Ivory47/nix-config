{ pkgs, inputs, ... }:

{
    home.packages = with pkgs; [
        inputs.matugen.packages.${system}.default
    ];


    # colours matching wallpaper
    xdg.configFile."matugen/config.toml".source = ./config.toml;

    xdg.configFile."matugen/templates/colors.conf".source = ./templates/colors.conf;

    xdg.configFile."matugen/templates/kitty.conf".source = ./templates/kitty.conf;

}
