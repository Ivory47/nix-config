{
    lib,
    stdenv,
    cmake,
    ninja,
    pkg-config,
    wayland,
    wayland-scanner,
    wlr-protocols,
    qt6,
}:

# The native part of the live glass pipeline: a QML module `Glass.Native` with GlassCapture
# (wlr-screencopy region capture, damage-aware scheduling, texture provider).
stdenv.mkDerivation {
    pname = "quickshell-glass-native";
    version = "0.1.0";

    src = lib.cleanSource ./.;

    nativeBuildInputs = [
        cmake
        ninja
        pkg-config
        wayland-scanner
        qt6.qtwayland
    ];

    buildInputs = [
        qt6.qtbase
        qt6.qtdeclarative
        qt6.qtwayland
        wayland
    ];

    dontWrapQtApps = true;

    cmakeFlags = [
        "-DWLR_SCREENCOPY_XML=${wlr-protocols}/share/wlr-protocols/unstable/wlr-screencopy-unstable-v1.xml"
    ];

    installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/qt-6/qml
        cp -r qml/Glass $out/lib/qt-6/qml/
        runHook postInstall
    '';
}
