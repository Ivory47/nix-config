{ config, pkgs, ... }:

# Pane: a Hyprland plugin that renders Quickshell's screen captures without Quickshell's own
# surfaces (see pane/main.cpp). It has to be built against the Hyprland that actually runs, so it
# is built here, from `programs.hyprland.package`, and installed to a fixed path that
# home-manager/gui/hyprland/hyprland.lua loads from (only if the file exists).
let
    pane = pkgs.callPackage ./pane/package.nix {
        hyprland = config.programs.hyprland.package;
    };
in
{
    environment.etc."hypr/plugins/libpane.so".source = "${pane}/lib/libpane.so";
}
