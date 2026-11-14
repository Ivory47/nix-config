{ lib, hyprlandPlugins, hyprland }:

# The plugin itself (see main.cpp). `hyprland` must be the package that actually runs: the plugin
# is built against its headers and checks its version hash when it loads.
hyprlandPlugins.mkHyprlandPlugin {
    pluginName = "pane";
    version = "0.1";
    inherit hyprland;

    src = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.unions [ ./main.cpp ./Makefile ];
    };

    installPhase = ''
        runHook preInstall
        mkdir -p $out/lib
        cp libpane.so $out/lib/libpane.so
        runHook postInstall
    '';

    meta = {
        description = "Clean screen captures for Quickshell's live glass";
        license = lib.licenses.mit;
    };
}
