{
    lib,
    stdenv,
    cmake,
    ninja,
    pkg-config,
    wayland,
    wayland-scanner,
    wlr-protocols,
    wayland-protocols,
    libgbm,
    libdrm,
    libglvnd,
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
        libgbm
        libdrm
        libglvnd
    ];

    dontWrapQtApps = true;

    cmakeFlags = [
        "-DWLR_SCREENCOPY_XML=${wlr-protocols}/share/wlr-protocols/unstable/wlr-screencopy-unstable-v1.xml"
        "-DLINUX_DMABUF_XML=${wayland-protocols}/share/wayland-protocols/stable/linux-dmabuf/linux-dmabuf-v1.xml"
    ];

    installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/qt-6/qml
        cp -r qml/Glass $out/lib/qt-6/qml/
        runHook postInstall
    '';
}
