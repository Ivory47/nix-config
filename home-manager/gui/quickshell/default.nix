{ pkgs, ... }:

let
    # A `qs -c <name>` config can only import files inside its own folder, so the
    # shared theme (./shared, used via `import qs.shared`) is copied into each config
    # at build time. There is still only one Theme.qml to edit.
    mkConfig = name: src: pkgs.runCommandLocal "quickshell-${name}" { } ''
        cp -r --no-preserve=mode ${src} $out
        rm -rf $out/shared
        cp -r --no-preserve=mode ${./shared} $out/shared
    '';
in
{
    home.packages = with pkgs; [
        quickshell # status bar, launcher and widgets
        qt6Packages.qt5compat
        cliphist # clipboard history for the clipboard popup
        wtype # only used if autoPaste is enabled in clipboard/ClipboardPopup.qml
    ];


    # quickshell
    xdg.configFile."quickshell/status-bar".source = mkConfig "status-bar" ./status-bar;
    xdg.configFile."quickshell/app-launcher".source = mkConfig "app-launcher" ./app-launcher;
    xdg.configFile."quickshell/clipboard".source = mkConfig "clipboard" ./clipboard;
}
