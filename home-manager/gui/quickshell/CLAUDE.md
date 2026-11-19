# CLAUDE.md — Quickshell configs (status bar, launcher, clipboard)

Permanent instructions for Claude Code sessions in this directory
(`home-manager/gui/quickshell/` inside the git repo `/home/user/src/nix-config`).
Facts below were verified from the repo unless marked **UNKNOWN**.

## 1. Project overview
Six Quickshell (QML/Qt6) shells for Hyprland, deployed through Home Manager:
`status-bar` (includes a self-rendered live glass/blur effect), `app-launcher`, `clipboard`, `settings`, `wallpapers` (all use the same glass, see sections 9, 10 and 12) and `notifications` (the notification server and its popups, section 13).
Goal of current work: a live background blur behind the status bar that is **independent of compositor blur**.
Since the Lucent plugin (section 11) the glass can use clean captures from Hyprland instead of estimating its own surface away; the old estimating pipeline (sections 8 and 9) is the fallback and is still what runs when the plugin is not loaded.

**Glass for a normal window (a `FloatingWindow`, or any window that is not a layer-shell popup): read `shared/glass/GLASS-WINDOWS.md` first.** It is the guide for using the Lucent plugin's compositor glass (`LucentGlass` / `LucentGlassPanel` / `GlassStyle`, the Hyprland window rule, the fallback without the plugin). Layer-shell popups use `GlassPopup` (section 9) instead; `shared/glass/LucentListPanel.qml` is the window counterpart of `GlassListPanel` (search field + list/grid highlights). The wallpaper picker (section 12) is the example of a window with glass.


## 2. Layout notes (the file tour and tech-stack list were removed: `ls` and `default.nix` show them)
- `default.nix` `mkConfig` copies each config folder into the store and copies `./shared` into it (a config can only import files in its own folder; imported as `qs.shared`). The glass C++/GLSL/tools sources are removed; only compiled `.qsb` shaders ship. `quickshell`/`qs` are wrapped so `QML_IMPORT_PATH` includes the `Glass.Native` module.
- `app-launcher/` and `clipboard/` are full-screen overlay popups with the glass; out of scope for status-bar work. `Test.qml` and the empty `LauncherSearch.qml` in the launcher are unused.

## Checking changes without running them: `./check.sh` (run it before `hms`)
Fails on untracked files (the flake cannot see them), on types or imports qmllint cannot resolve (all six shells, every file), on members read through a parent reference (`required property var overlay/pane/picker/panel/page`: qmllint cannot see those, `refs` does) and on a failing build of this device's Home Manager config (`NIX_CONFIG_TYPE`). `check.sh lint|refs|build` runs one part, `-v` shows every qmllint warning. Needs `qmllint` (installed by `default.nix`) and python3. It checks that things resolve, not that they look or behave right.

## Shared building blocks (read before writing a store, a popup or a bar layout)
- `shared/JsonFile.qml`: a JSON file for a store (load, watch from any process, retry while missing, debounced `save()`, `write()`, folder creation, own writes not read back). Used by `ThemeFromSettingsApp`, `NotificationHistory`, `WallpaperStore`, `LauncherModes`, `ColorCache`; use it for any new store.
- Popups: `shared/glass/GlassPopup`, `GlassSearchPopup` + `GlassListRow`; windows: `GlassWindow` + `GlassWindowPanel`; scrolling: `shared/KineticScroll`; one-widget-at-a-time and the close key: `shared/Widgets.qml`, `close-widget.sh` (details in `shared/glass/CLAUDE.md`). Bar: `status-bar/BarWindow`, `BarCatcher`, `BarMenu` (see `status-bar/CLAUDE.md`).

## Detail docs (load automatically when you work in these folders; read them first when a task touches them)
- `shared/glass/CLAUDE.md`: section 8 (status bar and background blur, clean mode, lessons), section 9 (glass on launcher and clipboard, testing without touching the real config, IPC and restarting) and section 11 (the Lucent plugin). Also `shared/glass/GLASS-WINDOWS.md`.
- `settings/CLAUDE.md`: section 10 (theme overrides, the settings app, Hyprland window rules page).
- `status-bar/CLAUDE.md`: the bar layouts (classic, balanced, islands, notch), the OSD and the notification history.
- `wallpapers/CLAUDE.md`: section 12 (wallpaper picker, overlay form). `notifications/CLAUDE.md`: section 13.
- Section numbers cited elsewhere ("section 9", ...) keep the original numbering, which the headings in those files carry.

## 4. NixOS environment and deployment workflow
- NixOS system with declaratively managed config. The repo is a **git repository whose root is `/home/user/src/nix-config`**; the Home Manager flake is `home-manager/flake.nix` (outputs `desktop`, `laptop`, `default`, `nas-server`); the system flake is `system/flake.nix`. `~/.config/home-manager` is a symlink to `<repo>/home-manager`.
- **`hms` is a zsh alias** (`home-manager/home.nix:86`):
  `hms = "_home-manager-switch && source ~/.config/zsh/.zshrc"`.
  `_home-manager-switch` (`home-manager/zsh/functions.zsh`) runs
  `home-manager switch --flake "$HOME/.config/home-manager#$NIX_CONFIG_TYPE" -b backup`
  (falls back to `#default` if `NIX_CONFIG_TYPE` is unset/unknown; `NIX_CONFIG_TYPE` is set per host in `system/hosts/*/configuration.nix`), then re-sources zshrc.
- `hms` only works in an interactive zsh (it is an alias). It does **not** restart or reload quickshell (no such command, no systemd unit found). After `hms`, use `qsr` to reload. Whether quickshell live-reloads by itself when its config symlink changes is **UNKNOWN**; do not rely on it.
- Startup: Hyprland runs `qs -c status-bar`, `qs -c app-launcher`, `qs -c clipboard` (`home-manager/gui/hyprland/hyprland.lua:62-64`).
- **`qsr` is the reload command.** It is a zsh alias (`home-manager/home.nix:87`):
  `qsr = "~/.config/home-manager/gui/quickshell/reload.sh"`.
  `~/.config/home-manager` is a symlink into this repo, so `qsr` executes the **repo's** `reload.sh` directly, not a nix-store copy. `default.nix` does not reference `reload.sh`, so it is never deployed by `hms`, and edits to it take effect immediately without `hms`.
  `qsr` is the alias and `reload.sh` is the file it runs; they do the same thing, but the alias exists only in interactive zsh. What `reload.sh` does: `pkill -f "quickshell -c <name>"` then `qs -c <name> >/dev/null 2>&1 & disown` for `status-bar` and `app-launcher`; for `clipboard` it kills the instance and any `wl-paste --type text|image --watch` watchers, then relaunches. So `qsr` restarts **all three** shells and discards their in-memory state. Before that, `reload.sh` makes sure the Lucent plugin is loaded: it loads `/etc/hypr/plugins/liblucent.so` if no plugin is loaded, unloads and loads it again if the installed build differs from the one it loaded last time (state file `lucent-build` in the Hyprland instance's runtime dir; unknown counts as different), and only warns if the old `pane` build is loaded (restart Hyprland). **So running `qsr` loads or swaps a plugin in the live compositor**: never run it from here without the user's explicit OK for that. Output is silenced, so QML errors are not shown.
  Claude Code's non-interactive shell does not have the alias: if a reload is approved, run the script path (`~/.config/home-manager/gui/quickshell/reload.sh`), after confirming its content is unchanged.
- To restart only the launcher or the clipboard, see section 9 (do not use `pkill -f` with the config name from Claude Code's shell).
- To restart only the bar: `pkill -f "quickshell -c status-bar"; qs -c status-bar >/dev/null 2>&1 & disown` (equivalent to the status-bar lines in `reload.sh`).
- **New files and flakes:** the flake lives in a git repo, so Nix only sees files tracked by git (staged or committed). A new untracked file is invisible to the build (standard Nix git-flake behaviour; not yet tested here). Stage only the specific new files needed (`git add <path>`).

### Apply-and-test sequence
1. Edit sources under `home-manager/gui/quickshell/`.
2. `git add` only newly created files the build needs (tracked-but-edited files are picked up automatically).
3. Ask the user for approval, stating what will be applied, then `hms` (updates the store paths behind `~/.config/quickshell/*`).
4. Ask the user for approval, then `qsr` (restarts the shells so they load the new config). Changes to `.qml`, shaders or `default.nix` need `hms` first; `qsr` alone would restart the old config.
5. Verify: `ls -l ~/.config/quickshell/` shows the new store path, the bar is running (`pgrep -af "quickshell -c status-bar"`), and the intended behaviour is observed. Run `qs -c status-bar` in a terminal if errors are suspected (reload.sh hides them).

### The Lucent plugin is deployed differently (system config, not `hms`)
- Source, Nix package/module, test tools and the full notes live in `~/Documents/Code/Lucent` (its own git repo; its CLAUDE.md is gitignored). The system flake has it as the input `lucent` (`git+file:///home/user/Documents/Code/Lucent`, `inputs.nixpkgs.follows`), `system/common/configuration-gui.nix` imports `inputs.lucent.nixosModules.default`, which builds it against `config.programs.hyprland.package` and installs `/etc/hypr/plugins/liblucent.so`. Needs a **system rebuild by the user** (never run `nixos-rebuild` from here; the system flake needs `--impure` because of `/etc/nixos/hardware-configuration.nix`).
- To change the plugin: edit and commit in Lucent, then `nix flake update lucent` in `system/` (a git+file input needs the commit), then the user rebuilds. The input path is absolute: every GUI host needs that directory (until Lucent is on GitHub).
- `hyprland.lua` loads it (guarded by "file exists", in `pcall`) when the config is read: at login, or on a config reload. Hyprland also reloads when `hms` changes the config, so **running `hms` after the rebuild can load the plugin into the running compositor**: tell the user before they do.
- **Never load a plugin into the user's live Hyprland to test it.** A plugin bug aborts the compositor and takes the whole session with it (this happened once: see Lucent's CLAUDE.md). Test in a headless nested Hyprland (recipe in Lucent's CLAUDE.md).

### Rules
- **Ask before running `hms` and ask before running `qsr`/`reload.sh`**, each time.
- Never substitute `hms` with `home-manager switch` or `nixos-rebuild switch`.
- Editing sources does not change the running system; only `hms` plus a shell restart does.
- Before deploying: explain what will be applied and ask for approval. Never run `hms` unprompted.
- After deploying: check for errors, then verify the change actually took effect (new store path linked in `~/.config/quickshell/status-bar`, bar restarted, behaviour observed).

## 5. Development commands
- Deploy (user approval required): `hms`.
- Reload (ask first): `qsr` = `reload.sh` (all three shells); bar only: see section 4.
- Inspect: `ls -l ~/.config/quickshell/` (store symlinks); `qs -c status-bar` in a terminal shows QML errors.
- Glass diagnostics: `qs ipc -c status-bar call glass stats` (IPC target `glass`; also `setCapture`, `setGlass`, `setProcessing`, `setDepth`, `setDmabuf`, `setWholeOutput`, `setInterval`, `setPoolLimit`, `setForceReject`, `setDiagnostics`); `shared/glass/tools/measure.py` drives it (`python3 measure.py [seconds] [scenario ...]`; scenarios `glass-off`, `capture-off`, `capture-only`, `normal`, `pool-2`, `reject`; default `glass-off` and `normal`). It runs from the repo, is not deployed, and changes live pipeline settings over IPC: it ends by restoring the normal settings and turning diagnostics off. `glass-off` temporarily replaces the glass with a plain rectangle.
- Glass latency: `shared/glass/tools/latency/run.sh <sweep|ramp|pulse|idle> <seconds> <tag>` (read its header). It starts a test background and a probe surface (same `GlassBackdrop` and `GlassPanel` as the bar) for a few seconds, both visible on screen, and leaves the running shells alone; `timeline.py` reads the probe's `WAYLAND_DEBUG` log and says for every compositor frame whether the glass got it one frame later (the floor), and if not, why (not captured, dropped as a duplicate, slow update). `GLASS_QML=<build>/lib/qt-6/qml` tests a `Glass.Native` build before `hms` (and `GLASS_SRC=1` the repository's `shared/glass/*.qml`); build one with `nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake "git+file:///home/user/src/nix-config?dir=home-manager"; pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.callPackage /home/user/src/nix-config/home-manager/gui/quickshell/shared/glass/native/package.nix {}'` (gives the deployed store path for an unchanged tree). `LAGCAP=1` with `pulse` records the real screen with Lucent's `lagcap` (`pulse.py`); that tool slows the compositor, so its numbers are higher than the timeline's.
- Existing IPC used by Hyprland: `qs ipc -c status-bar call events brightnessChanged`.
- Test/lint commands: none found. **UNKNOWN** whether any exist.

## 6. Git rules
- Inspect `git status` / `git diff` before and after every change.
- Stage only specific files you created that the build needs. Never `git add .` / `git add -A`.
- Never commit without explicit approval. Never discard or overwrite unrelated changes.

## 7. Coding and testing guidelines
- Understand existing code before changing it; prefer incremental improvements over rewrites; preserve existing functionality.
- Avoid new dependencies; keep things simple and maintainable.
- Write tests where appropriate; run the relevant build/lint/test checks; review your own diff critically.
- Explain important architectural decisions.
- Never claim something works without verification. Compiling/building is not the same as correct runtime behaviour.
- **Text centred in a pill, button, chip or badge: use `shared/CenteredText.qml`, not a `Text` with `anchors.centerIn`.** A plain Text is centred by its line box, which is as tall as the font's ascent + descent + leading (and taller when a symbol such as a star comes from a fallback font), so with some fonts the letters sit 1 to 3 px high or low. `CenteredText` puts the middle of the capital letters (`Text.baselineOffset` minus half of `FontMetrics.capitalHeight`) at the middle of its item, whatever the font; it takes the usual Text properties (`text`, `color`, `font.*`, `elide`, `horizontalAlignment`, `wrapMode`) and is as wide and tall as the text, so `anchors.centerIn: parent` and `anchors.verticalCenter` in a Row work as before. Not for single symbols (arrows, stars, ×, ↺): they have no cap height, keep a plain Text there. Measured (all-caps text in a pill, ImageMagick on a `grim` shot, 1.33 scale, six installed fonts including CaskaydiaCove Nerd Font, Red Hat Text, TeX Gyre Adventor, Noto Sans CJK, DejaVu Sans, Liberation Serif): mean error 0.75 px with a plain Text, 0.42 px with `CenteredText`, worst case 1.5 px to 1.0 px (DejaVu Sans, the font of the screenshots, from 1.5 px high to 0). Used in `Chip` (the tag pills, the segmented controls), the buttons and chips of the settings and wallpaper pages, the launcher's mode pill and the "Current" badges; other places still use plain Text (the bar, glass code, headings) and may need it if they look off.
- Status-bar tasks: work in `status-bar/`; read `shared/` or Nix files only when relevant. Do not explore `app-launcher/` or `clipboard/` unless the task is about them (then read section 9 first).
