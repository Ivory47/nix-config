#!/usr/bin/env bash
# Checks the quickshell configs without running them or touching the live session:
#   0. tracked: fails if there are files git does not track (the flake cannot see them).
#   1. lint:  qmllint over every .qml of every shell (also files that only load later, through a Loader).
#             Fails on a type that is not found or not resolved; everything else is only counted
#             (`-v` prints all of it).
#   2. build: builds the Home Manager config this device runs (NIX_CONFIG_TYPE: laptop, desktop, ...,
#             else `default`), through the same flake reference `hms` uses, so a file that git does not
#             track (invisible to the build) fails here and not after `hms`.
# Usage: check.sh [-v] [lint|build]      (no argument: both)
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
    lint) tracked || status=1; lint || status=1 ;;
    build) tracked || status=1; build || status=1 ;;
    all) tracked || status=1; lint || status=1; build || status=1 ;;
    *) echo "usage: check.sh [-v] [lint|build]"; exit 2 ;;
esac
exit $status
