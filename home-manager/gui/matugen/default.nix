{ pkgs, inputs, ... }:

{
    home.packages = with pkgs; [
        inputs.matugen.packages.${system}.default
    ];


    # colours matching wallpaper
    xdg.configFile."matugen/config.toml".source = ./matugen/config.toml;

    xdg.configFile."matugen/templates/colors.conf".source = ./matugen/templates/colors.conf;

    xdg.configFile."matugen/templates/kitty.conf".source = ./matugen/templates/kitty.conf;

}
