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
    # (preferences-system and the like), only app icons, so the app brings its own: an outlined eight-tooth gear.
    xdg.dataFile."icons/hicolor/scalable/apps/quickshell-settings.svg".text = ''
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
                  <g fill="none" stroke="#cdd6f4" stroke-width="4" stroke-linejoin="round">
                    <path d="M26.21,11.81 L27.13,2.90 L36.87,2.90 L37.79,11.81 A21.0,21.0 0 0,1 42.18,13.63 L49.13,7.98 L56.02,14.87 L50.37,21.82 A21.0,21.0 0 0,1 52.19,26.21 L61.10,27.13 L61.10,36.87 L52.19,37.79 A21.0,21.0 0 0,1 50.37,42.18 L56.02,49.13 L49.13,56.02 L42.18,50.37 A21.0,21.0 0 0,1 37.79,52.19 L36.87,61.10 L27.13,61.10 L26.21,52.19 A21.0,21.0 0 0,1 21.82,50.37 L14.87,56.02 L7.98,49.13 L13.63,42.18 A21.0,21.0 0 0,1 11.81,37.79 L2.90,36.87 L2.90,27.13 L11.81,26.21 A21.0,21.0 0 0,1 13.63,21.82 L7.98,14.87 L14.87,7.98 L21.82,13.63 A21.0,21.0 0 0,1 26.21,11.81 Z"/>
                    <circle cx="32" cy="32" r="12"/>
                  </g>
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
