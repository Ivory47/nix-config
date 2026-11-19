#!/usr/bin/env bash
# Checks the quickshell configs without running them or touching the live session:
#   0. tracked: fails if there are files git does not track (the flake cannot see them).
#   1. lint:  qmllint over every .qml of every shell (also files that only load later, through a Loader).
#             Fails on a type that is not found or not resolved; everything else is only counted
#             (`-v` prints all of it).
#   2. refs:  members read through an untyped parent reference (`required property var overlay`, `pane`, ...),
#             which qmllint cannot see, must exist on the parent (needs python3).
#   3. build: builds the Home Manager config this device runs (NIX_CONFIG_TYPE: laptop, desktop, ...,
#             else `default`), through the same flake reference `hms` uses, so a file that git does not
#             track (invisible to the build) fails here and not after `hms`.
# Usage: check.sh [-v] [lint|refs|build]      (no argument: all)
# Needs qmllint (qt6.qtdeclarative, installed by default.nix) and the profile's quickshell (`qs`).
set -u

verbose=0
[ "${1:-}" = "-v" ] && { verbose=1; shift; }
what=${1:-all}

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
status=0
red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

# Files git does not track are invisible to the flake: the build passes without them and the deployed
# shell then fails with "X is not a type" (the bar disappeared once like this).
tracked() {
    local files
    files=$(git -C "$here" ls-files --others --exclude-standard -- . ':!shared/glass/tools' 2>/dev/null)
    if [ -n "$files" ]; then
        red "tracked: files git does not track yet (git add them, hms cannot see them):"
        echo "$files" | sed 's/^/    /'
        return 1
    fi
    green "tracked: no untracked files"
}

lint() {
    command -v qmllint >/dev/null || { red "qmllint not found (run hms once: default.nix installs it)"; return 1; }
    local qs_bin qs_qml glass_qml
    qs_bin=$(readlink -f "$(command -v qs)") || return 1
    qs_qml="$(dirname "$qs_bin")/../lib/qt-6/qml"
    glass_qml=$(grep -o "/nix/store/[^']*glass-native[^']*/lib/qt-6/qml" "$qs_bin" | head -1)
    local qmllint_qml
    qmllint_qml="$(dirname "$(readlink -f "$(command -v qmllint)")")/../lib/qt-6/qml"
    local -a inc=(-I "$qs_qml" -I "$qmllint_qml")
    [ -n "$glass_qml" ] && inc+=(-I "$glass_qml")
    local IFS=:
    for p in ${QML2_IMPORT_PATH:-}; do [ -d "$p" ] && inc+=(-I "$p"); done
    unset IFS

    local tmp
    tmp=$(mktemp -d) || return 1
    trap 'rm -rf "$tmp"' RETURN

    # `import qs.shared` is a folder of the config: give qmllint the same layout as the deployed one
    # (a copy of ./shared inside each config), with a qmldir per folder (singletons marked).
    mkqmldir() { # dir module
        local d=$1 f n
        { echo "module $2"
          for f in "$d"/*.qml; do
              [ -e "$f" ] || continue
              n=$(basename "$f" .qml)
              if head -c 2000 "$f" | grep -q "pragma Singleton"; then echo "singleton $n 1.0 $n.qml"; else echo "$n 1.0 $n.qml"; fi
          done; } > "$d/qmldir"
    }
    # (The import root holds only `qs`: a config's own folder next to it would be taken for a module.)
    mkdir -p "$tmp/imp/qs" "$tmp/cfg"
    cp -r "$here/shared" "$tmp/imp/qs/shared"
    rm -rf "$tmp/imp/qs/shared/glass/native" "$tmp/imp/qs/shared/glass/shaders" "$tmp/imp/qs/shared/glass/tools"
    mkqmldir "$tmp/imp/qs/shared" qs.shared
    mkqmldir "$tmp/imp/qs/shared/glass" qs.shared.glass

    local cfg out bad total=0 failed=0
    for cfg in app-launcher clipboard notifications settings status-bar wallpapers; do
        cp -r "$here/$cfg" "$tmp/cfg/$cfg"
        rm -rf "$tmp/cfg/$cfg/glass-test"
        mkqmldir "$tmp/cfg/$cfg" "$cfg"
        out="$tmp/$cfg.txt"
        (cd "$tmp/cfg/$cfg" && qmllint -I "$tmp/imp" "${inc[@]}" --max-warnings 100000 ./*.qml > "$out" 2>&1)
        # Real problems: a type or module that is not found or resolved. Not counted: "margins"
        # (PopupWindow's anchor group has no type information) and the singleton notice qmllint gives
        # when it checks a singleton's own file (the qmldir above does declare it).
        bad=$(grep -E '^(Warning|Error):.*\[(import|unresolved-type)\]' "$out" | grep -v -e 'Type margins is used' -e 'not declared as singleton in qmldir' || true)
        total=$((total + $(grep -cE '^(Warning|Error):' "$out")))
        if [ -n "$bad" ]; then
            red "lint $cfg: unresolved types"
            echo "$bad" | sed 's/^/    /'
            failed=1
        elif [ "$verbose" = 1 ]; then
            echo "lint $cfg:"; cat "$out"
        fi
    done
    [ "$failed" = 0 ] && green "lint: all types resolve ($total other warnings, not failures; -v shows them)"
    return $failed
}

# A component that is told its parent through an untyped `required property var <name>` (WallpaperOverlay's
# parts, DetailPane's sections, ...) reads `<name>.x`, which qmllint cannot check. This does: every member the
# component reads must exist on the parent (a property, function or signal of the file whose root is passed in).
refs() {
    command -v python3 >/dev/null || { red "refs: python3 not found"; return 1; }
    python3 - "$here" <<'PY'
import os, re, sys
here = sys.argv[1]
BUILTIN = set("""width height x y z visible opacity enabled parent children data resources implicitWidth implicitHeight
devicePixelRatio screen color title contentItem contentWidth contentHeight activeFocus focus clip scale rotation
anchors state states transitions""".split())
bad = 0

# Every component of the tree by name, for the base types.
ALL = {}
for dd, _, ff in os.walk(here):
    if '/tools' in dd or 'glass-test' in dd:
        continue
    for f in ff:
        if f.endswith('.qml'):
            ALL.setdefault(f[:-4], open(os.path.join(dd, f)).read())

def read(p): return open(p).read()

def members(src):
    out = set(re.findall(r'\bproperty\s+(?:alias\s+|\w+(?:<[^>]*>)?\s+)?(\w+)\s*:', src))
    out |= set(re.findall(r'\bproperty\s+(?:alias\s+|\w+(?:<[^>]*>)?\s+)?(\w+)\s*\n', src))
    out |= set(re.findall(r'\bfunction\s+(\w+)', src))
    out |= set(re.findall(r'\bsignal\s+(\w+)', src))
    out |= set(re.findall(r'\bproperty\s+(?:alias\s+)?(?:\w+\s+)?(\w+)', src))
    return out

def root_id(src):
    m = re.search(r'^\w[\w.]*\s*\{\s*\n\s*id:\s*(\w+)', src, re.M)
    return m.group(1) if m else None

ALLMEM = {n: members(src) for n, src in ALL.items()}

for d, _, fs in os.walk(here):
    if '/tools' in d or 'glass-test' in d:
        continue
    qml = {f[:-4]: read(os.path.join(d, f)) for f in fs if f.endswith('.qml')}
    rid = {n: root_id(s) for n, s in qml.items()}
    mem = {n: members(s) for n, s in qml.items()}
    # A file inherits the members of the type it is based on, here or in shared/ (GlassSearchPopup is a
    # GlassPopup, WallpaperPicker a GlassWindow).
    def base(n):
        m = re.search(r'^(\w+)\s*\{', qml[n] if n in qml else ALL.get(n, ''), re.M)
        return m.group(1) if m and m.group(1) in ALL and m.group(1) != n else None
    for n in qml:
        b = base(n)
        seen = set()
        while b and b not in seen:
            seen.add(b)
            mem[n] |= ALLMEM.get(b, set())
            b = base(b)
    # (type, prop) -> list of (parent type) from instantiations "<Type> { ... prop: <expr>"
    def parents_of(ctype, prop, depth=0):
        found = set()
        if depth > 4:
            return found
        for g, gs in qml.items():
            if g == ctype:
                continue
            for m in re.finditer(r'\b' + ctype + r'\s*\{', gs):
                end = gs.find('\n', m.end())
                # the property assignments in the first lines of the block
                block = gs[m.end():m.end() + 600]
                a = re.search(r'\b' + prop + r':\s*([\w.]+)', block)
                if not a:
                    continue
                v = a.group(1)
                if v == rid.get(g):
                    found.add(g)
                elif '.' in v:
                    ident, p2 = v.split('.', 1)
                    if ident == rid.get(g):
                        found |= parents_of(g, p2, depth + 1)
                        continue
                    t = re.search(r'\b(\w+)\s*\{\s*(?://[^\n]*\n\s*)*id:\s*' + ident + r'\b', gs)
                    if t and t.group(1) in qml:
                        found |= parents_of(t.group(1), p2, depth + 1)
                elif g in qml:
                    t = re.search(r'\b(\w+)\s*\{\s*(?://[^\n]*\n\s*)*id:\s*' + v + r'\b', gs)
                    if t and t.group(1) in qml and False:
                        pass
        return found
    for c, cs in qml.items():
        for prop in re.findall(r'required property var (\w+)', cs):
            ps = parents_of(c, prop)
            if not ps:
                continue
            used = set(re.findall(r'\b' + prop + r'\.(\w+)', cs))
            for u in sorted(used):
                if u in BUILTIN:
                    continue
                for pt in ps:
                    if u not in mem[pt]:
                        print('    %s/%s.qml: %s.%s is not a member of %s.qml' % (os.path.relpath(d, here), c, prop, u, pt))
                        bad += 1
sys.exit(1 if bad else 0)
PY
    local rc=$?
    if [ $rc = 0 ]; then green "refs: every parent member read through a required property exists"; else red "refs: members read through a parent reference that the parent does not have (above)"; fi
    return $rc
}

build() {
    local type=${NIX_CONFIG_TYPE:-default}
    case "$type" in desktop|laptop|nas-server|default) ;; *) type=default ;; esac
    echo "build: home-manager config '$type' (the one hms uses on this device)"
    if nix build --no-link "$HOME/.config/home-manager#homeConfigurations.$type.activationPackage" 2>&1 | tail -n 15; [ "${PIPESTATUS[0]}" = 0 ]; then
        green "build: ok"
    else
        red "build: failed"
        return 1
    fi
}

case "$what" in
    lint) tracked || status=1; lint || status=1; refs || status=1 ;;
    refs) refs || status=1 ;;
    build) tracked || status=1; build || status=1 ;;
    all) tracked || status=1; lint || status=1; refs || status=1; build || status=1 ;;
    *) echo "usage: check.sh [-v] [lint|refs|build]"; exit 2 ;;
esac
exit $status
