{ runCommandLocal, qt6 }:

# Compiles every *.frag next to this file into a Qt shader pack (*.frag.qsb), which is what
# QML's ShaderEffect loads. WGSL cannot be used from QML; these are the GLSL ports of the
# same math (unmixing, check, blur, glass).
runCommandLocal "quickshell-glass-shaders" {
    nativeBuildInputs = [ qt6.qtshadertools ];
} ''
    mkdir -p $out
    for f in ${./.}/*.frag; do
        qsb --qt6 -o $out/$(basename "$f").qsb "$f"
    done
''
