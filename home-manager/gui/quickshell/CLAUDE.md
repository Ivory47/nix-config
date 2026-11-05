# CLAUDE.md — Quickshell configs (status bar, launcher, clipboard)

Permanent instructions for Claude Code sessions in this directory
(`home-manager/gui/quickshell/` inside the git repo `/home/user/src/nix-config`).
Facts below were verified from the repo unless marked **UNKNOWN**.

## 1. Project overview
Three Quickshell (QML/Qt6) shells for Hyprland, deployed through Home Manager:
`status-bar` (main focus, includes a self-rendered live glass/blur effect), `app-launcher`, `clipboard`.
Goal of current work: a live background blur behind the status bar that is **independent of compositor blur**.

## 2. Repository structure
- `status-bar/` — status bar. `shell.qml` (entry, one `StatusBar` per screen via `Variants`), `StatusBar.qml`, `Audio/Wifi/Battery*.qml`, menus, OSDs, `EventBridge.qml`, `glass-test/` (temporary test harness).
- `shared/` — `Theme.qml` plus `glass/` (the blur/glass implementation) and the legacy `BackdropBlur.qml` (unused).
- `default.nix` — Home Manager module that builds and installs all three configs.
- `reload.sh` — script that restarts all three quickshell instances; the zsh alias `qsr` runs it (see section 4).
- `app-launcher/`, `clipboard/` — out of scope for status-bar work unless a concrete dependency requires it.

## 3. Architecture and technologies
- QML on Quickshell; layer-shell via `PanelWindow` (`WlrLayershell.namespace: "statusbar"`).
- Glass/blur: `ShaderEffect`s with GLSL 440 shaders compiled to `.qsb`, plus a C++20 QML plugin `Glass.Native` (`shared/glass/native/`).
- Build deps (see `shared/glass/native/CMakeLists.txt`, `package.nix`): Qt6 (incl. private Quick/WaylandClient APIs), wayland-client, gbm, libdrm, EGL/GLES, wlr-protocols, wayland-protocols.
- `default.nix` details:
  - `glassNative` and `glassShaders` are built with `pkgs.callPackage`.
  - `quickshell`/`qs` are wrapped so `QML_IMPORT_PATH` includes the `Glass.Native` module.
  - `mkConfig` copies each folder into the store and copies `./shared` into it (a config can only import files in its own folder; imported as `qs.shared`). The glass C++/GLSL/tools sources are removed; only compiled `.qsb` shaders ship.
  - Result is linked to `~/.config/quickshell/{status-bar,app-launcher,clipboard}` (read-only `/nix/store` symlinks).

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
  `qsr` is the alias and `reload.sh` is the file it runs; they do the same thing, but the alias exists only in interactive zsh. What `reload.sh` does: `pkill -f "quickshell -c <name>"` then `qs -c <name> >/dev/null 2>&1 & disown` for `status-bar` and `app-launcher`; for `clipboard` it kills the instance and any `wl-paste --type image --watch` watchers, then relaunches. So `qsr` restarts **all three** shells and discards their in-memory state. Output is silenced, so QML errors are not shown.
  Claude Code's non-interactive shell does not have the alias: if a reload is approved, run the script path (`~/.config/home-manager/gui/quickshell/reload.sh`), after confirming its content is unchanged.
- To restart only the bar: `pkill -f "quickshell -c status-bar"; qs -c status-bar >/dev/null 2>&1 & disown` (equivalent to the status-bar lines in `reload.sh`).
- **New files and flakes:** the flake lives in a git repo, so Nix only sees files tracked by git (staged or committed). A new untracked file is invisible to the build (standard Nix git-flake behaviour; not yet tested here). Stage only the specific new files needed (`git add <path>`).

### Apply-and-test sequence
1. Edit sources under `home-manager/gui/quickshell/`.
2. `git add` only newly created files the build needs (tracked-but-edited files are picked up automatically).
3. Ask the user for approval, stating what will be applied, then `hms` (updates the store paths behind `~/.config/quickshell/*`).
4. Ask the user for approval, then `qsr` (restarts the shells so they load the new config). Changes to `.qml`, shaders or `default.nix` need `hms` first; `qsr` alone would restart the old config.
5. Verify: `ls -l ~/.config/quickshell/` shows the new store path, the bar is running (`pgrep -af "quickshell -c status-bar"`), and the intended behaviour is observed. Run `qs -c status-bar` in a terminal if errors are suspected (reload.sh hides them).

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
- Status-bar tasks: work in `status-bar/`; read `shared/` or Nix files only when relevant. Do not explore `app-launcher/` or `clipboard/`.

## 8. Status bar and background blur architecture
Wiring: `status-bar/StatusBar.qml` contains `GlassPanel` (inside `barContent`) and a sibling `GlassBackdrop { composite: barContent; blurRadius: 14; ipcTarget: "glass" }`.

Pipeline (`shared/glass/`; read from code, with the behaviour below measured on the laptop, 1920x1080 at scale 1.333):
1. **Acquire:** `GlassCapture` (`native/glasscapture.cpp`) uses `zwlr_screencopy_manager_v1` `copy_with_damage` into GBM dmabufs (EGLImage import, wl_shm fallback). Whole output is captured by default (works around a suspected Hyprland per-region session leak; the shader crops the bar region). Throttled to one per refresh period; sparse-sample dedupe drops unchanged frames.
2. **Remove the bar from its own capture:** `unmix.frag`: `bg = (capture - own.rgb) / (1 - own.a)`, where `own` is the bar's presented content. The bar is drawn at alpha ≈0.88 (`GlassStyle`) so the background stays recoverable. `settle.frag`/`verdict.frag` reject bad captures (previous background is kept).
3. **Blur:** `blur.frag`, separable Gaussian via `GlassBundle.qml` (full→half size, then vertical at half size; RGBA16F; max 48 taps/side).
4. **Present:** three `GlassBundle`s are rotated, flipping only after a synced frame; captures are held back (`cap.held`) from the moment a capture lands until `releaseMargin + 1` frames with the new glass have been presented (`process()`, `handleSwapped()`, `release()`, 120 ms watchdog); `GlassPanel` + `glass.frag` draw refraction (bottom edge), dispersion, tint, shine.
5. **Refresh:** event-driven (compositor damage and `onFrameSwapped`), no polling. Measured with a window dragged behind the bar: about 15 captures and updates per second, all accepted. Not yet at the monitor's refresh rate (see below).

Hyprland / independence: `hyprland.lua` has no `layer_rule` for `statusbar`; no `ext-background-effect` or toplevel-export protocols are used, so the blur is computed entirely in the shell. Hyprland's global `decoration.blur` is enabled (`hyprland.lua:~145-150`) but affects only window content seen in the capture. Requires wlr-screencopy + dmabuf from the compositor; code is tuned to Hyprland 0.56.x behaviour.

Lessons that cost time (all verified by experiment on the desktop; keep these in mind when changing `shared/glass/`):
- **Hidden `ShaderEffectSource`s are rendered lazily.** Qt rendered a non-live, hidden source only when something visible sampled it, so an update of a bundle that was not shown waited until it was shown, and was then rebuilt while shown (its `kept` was itself: the bar flashed plain tint, then noise, then magenta in a marker experiment). The keep-alive consumers (the `Repeater` of tiny off-window `ShaderEffect`s in `GlassBackdrop.qml`) make scheduled updates render at once. Do not remove them.
- **A capture must not overlap a change of the glass.** The unmix compares the capture with the bar's content as rendered now. If the glass changed between the captured frame and now, the capture is rejected (or accepted with wrong colours). Rejection during a window drag, from the loosely trusted counters: about 82% with overlapping captures, about 48% with captures held until the new glass was presented, 0% with one more frame of margin (`releaseMargin: 1`).
- **The validation counters read back through `grabToImage` (`decode()`, `readout.frag`) are partly corrupt**: wrong-frame and unusable were always equal, "held last good" went negative, "valid backdrop seen" stayed false, "last" percentages exceeded 100%. Trust only accepted / rejected totals, the capture counters and CPU numbers, and only loosely.
- `measure.py` restores the normal settings in a `finally`; it measures CPU only (no GPU, memory or power).
- Never put the string `quickshell -c status-bar` in a command run from Claude Code's shell: `reload.sh` uses `pkill -f` on it and kills the calling shell.

Constraints / known limitations:
- Update rate is about 15 per second, one capture cycle at a time; matching the refresh rate needs overlapping captures with a per-frame history of the bar's own content (not implemented). The blur trails the content by roughly 100 ms or more.
- Rarely a colourful-noise frame was seen while dragging a window (before the margin fix); not seen since, but unconfirmed.
- Unmix needs an exact match with the presented bar frame; animation, fades, or fractional-scale mismatch cause rejected captures. A rejected capture keeps the background that is on screen.
- Dividing by (1 − 0.88) amplifies 8-bit noise (thresholds hand-tuned); background is unknown under opaque bar content.
- Popups/OSDs/notifications overlapping the bar region are captured as "background".
- Whole-output capture cost scales with resolution and monitor count; dmabuf pool up to 12 buffers per monitor (memory estimate unmeasured).
- Hardcoded: `origin` (0,0) (top bar only), `blurRadius` 14; no output-transform handling seen; relies on Qt private APIs.
- Dead code: `shared/BackdropBlur.qml` (+ `Theme.backdropBlur`), `status-bar/glass-test/`, commented-out fade in `StatusBar.qml`.
- Still **UNKNOWN**: GPU use, memory, power, multi-monitor behaviour, and behaviour at other scales.
