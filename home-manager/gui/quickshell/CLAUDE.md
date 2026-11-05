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
Wiring: `status-bar/StatusBar.qml` contains `GlassPanel` and a one-pixel `GlassTag` (both inside `barContent`) and a sibling `GlassBackdrop { composite: barContent; blurRadius: 14; ipcTarget: "glass" }`.

Pipeline (`shared/glass/`; read from code, with the behaviour below measured on the laptop, 1920x1080 at scale 1.333, Hyprland 0.56):
1. **Acquire:** `GlassCapture` (`native/glasscapture.cpp`) uses `zwlr_screencopy_manager_v1` `copy_with_damage` into GBM dmabufs (EGLImage import, wl_shm fallback). Whole output is captured by default (works around a Hyprland per-region session leak at fractional scales; the shader crops the bar region). One request in flight, at most one per refresh period; a sparse-sample duplicate check (`sameAsBefore`: about a thousand green-channel samples of the bar region, compared with the last published capture) drops unchanged captures. A capture is new if one sample moved by more than 3 levels, or if at least 10 samples (1% if more) moved by 1 or more; the second rule catches slow, faint changes such as a wallpaper fade. This is what keeps an idle desktop quiet: about 2.5% CPU, no updates.
2. **Remove the bar from its own capture:** `unmix.frag`: `bg = (capture - own.rgb) / (1 - own.a)`. `own` is the bar as it was in the frame the compositor captured, which is not always the latest one. Every presented version of the bar is kept in a ring of 8 snapshots (`r0..r7` in `GlassBackdrop.qml`, one taken per update), and one opaque pixel at the top left of the bar (`GlassTag.qml`, blue = 46 + 4 * (version % 8), red and green 30) tells the shader which version a capture holds (the compositor copies opaque pixels exactly). A capture whose tag is not ours, or not kept, is rejected. `settle.frag` keeps the previous background when a capture is rejected (more than 1% of pixels wrong, or more than 60% unknown).
3. **Blur:** `blur.frag`, separable Gaussian via `GlassBundle.qml` (full to half size, then vertical at half size; RGBA16F; max 48 taps/side).
4. **Present:** three `GlassBundle`s are rotated. `process()` builds the update into the bundle that is not on screen and shows it at once: the frame that renders it also draws the glass with it (Qt renders what a texture needs before the item that samples it). `readIdx` is the bundle on screen, `prevIdx` the one before it (`last`: what is kept on rejection, and the unmix's `previous`). A capture that arrives before the previous update was synchronised is folded into it (`scheduledAt`). `GlassPanel` + `glass.frag` draw refraction (bottom edge), dispersion, tint, shine. The glass draws with alpha 0.92 (`GlassStyle.alpha`) and subtracts the leak of the background it estimated.
5. **Refresh:** event-driven (compositor damage and frame swaps). Measured with a moving background behind the bar: about 54 captures, updates and accepted frames per second (nothing rejected), 60 window frames per second, bar CPU about 16-18% (render thread about 9%, main thread about 5.5%, the two Wayland event threads about 3.5%), Hyprland about 14% (its main thread). Idle: no updates.
6. **Latency:** the blur trails fast content by about 35-90 ms (about 1 cm at 14 inch for the fastest sweeps in the test harness), roughly 3 frames: the compositor frame that has the change and answers the capture (11-16 ms measured request to ready), our frame that renders the update, the compositor frame that composites it. Each step is quantised by the frame cycle; the one avoidable frame (showing the update a frame after rendering it) is already removed.

Hyprland / independence: `hyprland.lua` has no `layer_rule` for `statusbar`; no `ext-background-effect` or toplevel-export protocols are used, so the blur is computed entirely in the shell. Hyprland's global `decoration.blur` is enabled (`hyprland.lua:~145-150`) but affects only window content seen in the capture. Requires wlr-screencopy + dmabuf from the compositor; code is tuned to Hyprland 0.56.x behaviour.

Lessons that cost time (all verified by experiment on the desktop; keep these in mind when changing `shared/glass/`):
- **Hidden `ShaderEffectSource`s are rendered lazily.** Qt rendered a non-live, hidden source only when something visible sampled it. Updates of a bundle that was not shown waited until it was shown and were then rebuilt while shown (the bar flashed plain tint, then noise, then magenta in a marker experiment), and the ring snapshots would never render. The keep-alive consumer in `GlassBackdrop.qml` (one tiny off-window `ShaderEffect`, `shaders/keepalive.frag`, sampling all 14 scheduled textures; its output must depend on every sampler or the unused ones are optimised away) makes scheduled updates render. Do not remove it.
- **A capture must be unmixed against the bar version it holds.** The compositor can answer with the bar as it was one or two frames earlier, and the glass changes with every update. Without the tag, rejection during a window drag was about 82% with overlapping captures, about 48% with captures held until the new glass was presented, 0% with two frames of margin, but only about 15 updates per second that way. The tag and the ring give about 54 per second with nothing rejected. (A "best matching candidate" selection by counting wrong pixels cannot work: the range test cannot tell similar versions apart.)
- **Texture cycles:** a bundle must never read its own output (`kept` is `draftSource` for the previous bundle), and the unmix's `own` sampler for the ring slot rendered in the same frame is swapped for another slot (otherwise the snapshot would wait for the unmix and the unmix for the snapshot).
- **The duplicate check must be sensitive to faint changes.** The glass covers the background (alpha 0.92: only 8% of it shows in the capture, 12% at 0.88), so a background change of N levels moves a capture sample by about N/12. With the original rule (any sample by more than 3) a slow `awww` wallpaper transition needed about 40 levels of change before it registered: measured over a transition, about 200 captures arrived and only about 8 were published (at most 5 per second). With the 1%-of-samples rule a transition publishes bursts of 50-100 captures (up to 51 per second) and an idle desktop still publishes nothing. Raising `GlassStyle.alpha` lowers the sensitivity further.
- **The validation counters read back through `grabToImage` (`decode()`, `readout.frag`) are partly corrupt** (wrong-frame and unusable were identical, "held last good" went negative, "valid backdrop seen" stayed false, "last" percentages exceeded 100%). Trust accepted / rejected totals loosely, and the capture counters (`requests`, `published`, `duplicates`, `frames`) and CPU numbers. The counting pass now runs only while diagnostics are on; `measure.py` turns diagnostics on, so its bar CPU is a little higher than in normal use (use per-thread `/proc` samples for that).
- `measure.py` restores the normal settings in a `finally`; it measures CPU only (no GPU, memory or power). `perf` is not installed and `strace` cannot attach (`ptrace_scope` 1): per-thread CPU from `/proc/<pid>/task/*/stat` is the finest profile available.
- **Compare with Pleamar** (`github.com/k4ditano/pleamar`, Rust + wgpu; `marea-plm` is only an app built on it and has no blur code; BSD-3-Clause). Our pipeline is a port of its lens: `src/lens.rs` (`Lens::receive`, `Frost::run`), `src/blur.rs` (blur passes), `src/backdrop.wgsl` and `src/backdrop_check.wgsl` (unmix and judging), `src/platform/capture.rs`, `src/shape.wgsl`. Its duplicate check is the same as ours was (one byte in 13, tolerance 3), so it is not a source for faint-change detection. It differs in: region capture with a `reach` margin (we capture the whole output because of the Hyprland session leak), at most one capture per 50 ms, no tag or frame history (the surface waits for the screenshot, serialised), samples of pixels its own scene repainted are excluded from the comparison, an identical capture is taken in once more before being ignored, a capture is lost after 500 ms and a still-screen poll every 250 ms for a Hyprland quirk. `lens = image` uses a picture file as the backdrop instead of a capture. Read only as far as `lens.rs` lines 131-420 and its constants; its capture pacing, blur source and read-back were not read.
- Never put the string `quickshell -c status-bar` in a command run from Claude Code's shell: `reload.sh` uses `pkill -f` on it and kills the calling shell.
- **Test load without dragging a window:** a second Quickshell instance (`qs -p file.qml`, started and killed by PID) with a `PanelWindow { aboveWindows: false; exclusionMode: ExclusionMode.Ignore; anchors top/left/right; implicitHeight: 160 }` on the Bottom layer, under the bar, with a few coloured `Rectangle`s sweeping across with `NumberAnimation on x { loops: Animation.Infinite }`. Check with `hyprctl layers` that it is on the bottom layer; remove it afterwards. A first start once produced a static scene; check that `published/s` is near 54.

Constraints / known limitations:
- **Visible tag pixel (temporary, to revisit):** one real pixel at the top left of the screen changes by a few 255ths of blue per update. The alternative discussed: carry the tag in pixels that are opaque anyway (clock, workspace numbers, icons: shift their colour by a few 255ths and match opaque pixels per ring slot), or match timestamps (`wp_presentation`), which needs C++. The tag requires the bar at the top left of the output.
- Ring depth is 8 versions: a capture more than 8 updates old by the time it is unmixed would be unmixed against the wrong slot (not seen at 11-16 ms capture latency).
- Dividing by (1 - alpha) amplifies capture errors: 8.3x at 0.88, 12.5x at 0.92; the background cannot be recovered at all from 0.97 up. Background is unknown under opaque bar content.
- Text, clock or animation changes between updates are not in the ring: a few pixels mismatch until the next update (well under the 1% threshold).
- Popups/OSDs/notifications overlapping the bar region are captured as "background".
- Whole-output capture cost scales with resolution and monitor count; dmabuf pool up to 12 buffers per monitor (memory estimate unmeasured).
- Hardcoded: `origin` (0,0) (top bar only), `blurRadius` 14; no output-transform handling seen; relies on Qt private APIs.
- Dead code: `shared/BackdropBlur.qml` (+ `Theme.backdropBlur`), `status-bar/glass-test/`, commented-out fade in `StatusBar.qml`.
- Still **UNKNOWN**: GPU use, memory, power, multi-monitor behaviour, and behaviour at other scales. A rare colourful-noise frame was seen once while dragging, before the tag; not seen since, but unconfirmed.
