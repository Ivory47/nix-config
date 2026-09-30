{ pkgs, inputs, ... }:

{
    home.packages = with pkgs; [
        wl-clipboard
        inputs.hyprmod.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # force is required cause hyprmod deletes the symlink :/
    xdg.configFile."hypr/hyprland.lua" = {
        source = ./hypr/hyprland.lua;
        force = true;
    };

    xdg.configFile."matugen/templates/hyprland.lua".source = ../matugen/templates/hyprland.lua;
}
