{ pkgs, ... }:

{
    home.packages = with pkgs; [
        quickshell # status bar, launcher and widgets
        qt6Packages.qt5compat
    ];


    # quickshell
    xdg.configFile."quickshell/status-bar".source = ./status-bar;
    xdg.configFile."quickshell/app-launcher".source = ./app-launcher;
}
