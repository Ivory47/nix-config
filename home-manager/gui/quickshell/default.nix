{ pkgs, ... }:

let
    # Live liquid glass (shared/glass), used by the status bar, the app launcher and the clipboard popup.
    #  - glassNative: the QML module `Glass.Native` (wlr-screencopy region capture), C++.
    #  - glassShaders: the GLSL shaders compiled to .qsb, which is what QML's ShaderEffect loads.
    glassNative = pkgs.callPackage ./shared/glass/native/package.nix { };
    glassShaders = pkgs.callPackage ./shared/glass/shaders/package.nix { };

    # quickshell, able to find the Glass.Native module.
    quickshellWithGlass = pkgs.symlinkJoin {
        name = "quickshell-with-glass";
        paths = [ pkgs.quickshell ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
            for bin in qs quickshell; do
                if [ -e "$out/bin/$bin" ]; then
                    wrapProgram "$out/bin/$bin" \
                        --prefix QML_IMPORT_PATH : ${glassNative}/lib/qt-6/qml \
                        --prefix QML2_IMPORT_PATH : ${glassNative}/lib/qt-6/qml
                fi
            done
        '';
    };

    # A `qs -c <n>` config can only import files inside its own folder, so the
    # shared theme (./shared, used via `import qs.shared`) is copied into each config
    # at build time. There is still only one Theme.qml to edit.
    # The glass sources (C++ and GLSL) are not needed at run time: only the compiled shaders.
    mkConfig = name: src: pkgs.runCommandLocal "quickshell-${name}" { } ''
        cp -r --no-preserve=mode ${src} $out
        rm -rf $out/shared
        cp -r --no-preserve=mode ${./shared} $out/shared
        rm -rf $out/shared/glass/native $out/shared/glass/shaders $out/shared/glass/tools
        mkdir -p $out/shared/glass/shaders
        cp ${glassShaders}/*.qsb $out/shared/glass/shaders/
    '';
in
{
    home.packages = with pkgs; [
        quickshellWithGlass # status bar, launcher and widgets
        qt6Packages.qt5compat
        cliphist # clipboard history for the clipboard popup
        wtype # only used if autoPaste is enabled in clipboard/ClipboardPopup.qml
    ];


    # quickshell
    xdg.configFile."quickshell/status-bar".source = mkConfig "status-bar" ./status-bar;
    xdg.configFile."quickshell/app-launcher".source = mkConfig "app-launcher" ./app-launcher;
    xdg.configFile."quickshell/clipboard".source = mkConfig "clipboard" ./clipboard;
    xdg.configFile."quickshell/settings".source = mkConfig "settings" ./settings;

    # The icon of that entry: Quickshell's icon lookup does not find the generic theme icons
    # (preferences-system and the like), only app icons, so the app brings its own.
    xdg.dataFile."icons/hicolor/scalable/apps/quickshell-settings.svg".text = ''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
          <circle cx="32" cy="32" r="26" fill="none" stroke="#cdd6f4" stroke-width="8" stroke-dasharray="8.5 8.5"/>
          <circle cx="32" cy="32" r="20" fill="none" stroke="#cdd6f4" stroke-width="10"/>
        </svg>
    '';

    # Lets the app launcher (and any other launcher) open the settings app: it toggles the
    # running `qs -c settings` instance over IPC.
    xdg.desktopEntries.quickshell-settings = {
        name = "Shell Settings";
        genericName = "Settings";
        comment = "Theme settings for the status bar, launcher and clipboard";
        exec = "qs -c settings ipc call settings toggle";
        icon = "quickshell-settings";
        terminal = false;
        categories = [ "Settings" ];
    };
}
