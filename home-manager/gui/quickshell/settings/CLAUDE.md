# CLAUDE.md — the settings app (`settings/`, config `qs -c settings`; original section 10)

A reference for working here, not a history (git has that). Facts were verified when written; "NOT checked"
marks what only lint and build covered. Shared glass details: `../shared/glass/CLAUDE.md`,
`../shared/glass/GLASS-WINDOWS.md`.

## 1. What it is
Settings for the whole Quickshell setup: the Theme (values every shell reads), the Hyprland window rules with
glass parameters, and the settings app's own keys. **Two hosts, one content.** `Settings.qml` is the
full-screen overlay (a `GlassPopup` with a veil; namespace `settings`; do not open it together with the
launcher). `SettingsWindow.qml` is a normal `FloatingWindow` with compositor glass (`LucentListPanel`; created
in a `Loader` only while open). Both show `SettingsView.qml` (`glassOn` false = plain fills; it asks the host to
close with `closeRequested()`). IPC target `settings` (`shell.qml`): `toggle`/`show` overlay, `toggleWindow`/
`showWindow` window, `hide` both, `isOpen` the overlay only (the Super+C bind in `hyprland.lua` uses it: the app
is a layer surface, so Hyprland swallows the key). The bar's gear button opens the overlay; the launcher lets the
user choose which form an app row opens. Started at login by `hyprland.lua` and by `reload.sh`.

## 2. Folders (layers that never import upwards; imported as `qs.<folder>`)
The config root holds only `shell.qml`, `Settings.qml`, `SettingsWindow.qml`, `SettingsView.qml`, `Sidebar.qml`,
`SearchResults.qml`. A root file may use the folders; **a folder file must not use a root file** (the root is
not a module; QML module imports must not form a cycle). A new file goes into the folder of its layer and
needs `git add` (flakes) and `import qs.<folder>` for the types it uses (`check.sh lint` reports a missing
import as an unresolved type).
- `core/` — no UI, imports only `qs.shared`: `ThemeStore` (edits and writes the Theme file), `AppSettings` (the
  app's own settings file), `SettingsHistory`, `SettingsIndex` (categories, search), `ThemeSchema`, `AppSchema`
  (what the pages show), `GlassParams` (the glass look parameters, defined once), `ThemeActions`, `AppDefaults`,
  `FieldKeys`, `KeyMap`.
- `controls/` — plain widgets: `ActionButton`, `Segmented`, `SettingsSlider`, `Stepper`, `ValueText`, `Toggle`,
  `Chevron`, `Collapsible`, `KeyCap`, `TextRow`, `PageHeader`, `SettingsPage` (the scrolling page),
  `KineticFlickable`, `FlashFrame`, `BlockTitle`, `ResetButton`, `SettingsLabel`.
- `fields/` — one setting row each: `SettingsRow` (label, note, control column, reset arrow), the
  `Number`/`Choice`/`Switch`/`Color`/`Link`/`Keys` fields, and `SettingField` (picks the field by `spec.type`).
- `theme/` — the Theme pages: `ThemePage`, `ThemeSection`, `ThemeGroup`, `ColorGrid`, `SizeTable`,
  `GlassWidgetRow`, `SettingsBlock`.
- `hyprland/` — Window rules: `HyprlandPage`, `RuleCard`, `BaseRuleList`, `GlassParamBlocks`, and the stores
  `HyprlandStore` (rules, edits, validation, writing, reload), `RuleLua` (rules <-> the Lua text),
  `BaseRules` (reads the base config's rules), `GlassParamStore` (a rule's parameters as a store for fields).
- `keys/` — vim keys: `KeyNav` (the handler and the action table), `NavStops`, `NavCursor`, `KeyHelp`.

## 3. Recipes
- **A Theme value:** a line in `shared/ThemeDefaults.qml`, one in `shared/Theme.qml` with the same name, an
  entry in `core/ThemeSchema.qml`. The page, search, reset, undo, the sidebar's "changed" dot and the keyboard
  come from the schema; `ThemePage` has no per-value code. A schema item: `key` (a path for grouped values:
  `"glassBar.frost"`), `label`, `type` (`color`, `number` with `kind` `int`/`real` and `min`/`max`/`step`,
  `bool`, `choice` with `options`, `link`, `keys`), `note`, `keywords` (search synonyms), `showIf: { key, is }`,
  `inherits` (dimmed while it follows another value). Read values with `ThemeStore.value(key)` and defaults
  with `ThemeStore.defaultOf(key)`, never `Theme[key]`.
- **A glass look parameter:** one entry in `core/GlassParams.qml` (range, label, note, plugin default, search
  words), the property in `shared/GlassLook.qml` and a value in each look in `ThemeDefaults`. The Theme pages
  (`ThemeSchema.lookBlocks`) and the window rules (`HyprlandStore.glassParams`, `defaultLookParams`) both
  build from it.
- **A field type:** a file in `fields/` based on `SettingsRow`, using `root.store.*` (never `ThemeStore.*`
  directly), and a branch in `SettingField`.
- **A row on another store:** give `SettingField` a `store` with `value`, `defaultOf`, `isSet`, `set`,
  `preview`, `commit`, `reset` (a colour also `setLive`, `colorString`, `openColor`); `readOnly: true` locks the
  rows. `hyprland/GlassParamStore.qml` is the example. A key a store does not hold needs `ThemeStore`
  to route it (`ThemeStore` hands `keyboard.*` and `keys.*` to `AppSettings`).
- **A page:** a category (in `ThemeSchema.categories` / `AppSchema.categories`, or one entry in
  `SettingsIndex.categories` for a page of its own) with `id`, `group`, `name`, `icon`, `description`,
  `actions`, `sections`. `SettingsView` builds the pages from `SettingsIndex.categories` (a `Repeater` of
  `Loader`s: `ThemePage { catId }`, or `HyprlandPage` for `windowRules`): a page with its own component is a
  branch there. A page with its own state implements `scrollTo(key, gentle)` (opens what has to be opened and
  calls `FlashFrame.flash`), `navItemFor(key)` (where the keyboard cursor goes after a jump) and optionally
  `navResetPage()`. To add a top-level group: an entry in `SettingsIndex.groups`.
- **A store that takes part in undo / redo:** `SettingsHistory.register(store, () => state, s => { put the
  state back; commit() }, locate?)` once, `SettingsHistory.committed(store)` at the start of its `commit()`,
  `SettingsHistory.rebase(store)` when state is read from outside (file load, migration). `locate(from, to)`
  returns `{ catId, key }` so that an undo shows what changed. `ThemeStore`, `AppSettings` and `HyprlandStore`
  are registered. One step = one `commit()` (commits within 600 ms merge; a drag is one step because `preview()`
  does not commit).
- **A section that opens:** `controls/Collapsible` (header with chevron, title, note, "N changed" badge; the
  content is its children; it only reports `toggled(open)`).
- **A keyboard stop:** see section 5.

## 4. Data, files and stores
- **Theme file:** `~/.config/quickshell-settings/settings-app-theme.json` (outside the store, survives `hms`):
  only the changed keys, grouped values nested (`{"glassBar": {"tintStrength": 0.45}}`). Read by
  `shared/ThemeFromSettingsApp` (`FileView`, `watchChanges`), so every shell updates live; a file that does not
  exist at start is found by a 2 s retry. In memory a grouped key is a path (`"glassBar.tintStrength"`; `flatten`
  on read, `nest` on write). `ThemeStore`: `preview` changes this process only (drags), `commit()` writes (30 ms
  coalesced), `set` = both; a value equal to its default is removed. `ownWrites` makes the loader ignore reads
  of its own recent writes. `ThemeStore.migrate()` rewrites old flat keys (`glassBarTintStrength`, ...) once.
- **Settings-app file:** `~/.config/quickshell-settings/settings-app.json`, only what differs from
  `core/AppDefaults.qml` (the app's keys and mode), through `AppSettings`.
- **Glass looks:** every widget has a `GlassLook` in `Theme` with `base: glassDefault` (`glassBar`,
  `glassBarPanels`, `glassLauncher`, `glassClipboard`, `glassSettings`, `glassWallpapers`, `glassNotifications`,
  `glassWallpaperOverlay`). `<name>.look` ("default" / "own") picks `inUse`; a value an own look does not set is
  the default look's, live (`GlassLook.fallback`; `ThemeStore.defaultOf` asks the look, so a value set back to
  the default is dropped). Widgets draw with `Theme.glassX.inUse`. `ThemeDefaults` holds only what differs.
- **Window rules** (`hyprland/`): rules are written to `home-manager/gui/hyprland/hyprland-settings.lua`
  (in `.gitignore`; env `HYPRLAND_SETTINGS_FILE` overrides it for tests), which `hyprland.lua` `dofile`s at its
  END, so a later rule wins and the first rule of the list is written LAST. The file holds the rules as Lua
  inside `if io.open("/etc/hypr/plugins/liblucent.so")` (`lucent_glass` is an error without the plugin) and, in
  a `--[====[ quickshell-settings ... ]====]` comment, the same rules as JSON, which is what the app reads back
  (do not edit the file by hand). After a change (600 ms pause) the store writes it and runs `hyprctl reload`
  (it re-applies to windows that are already open), then reads `hyprctl configerrors` 800 ms later and shows
  the lines about this file. `configerrors` does NOT report an invalid regex or a bad `lucent_glass` string: the
  app validates regexes (JS `RegExp`) and the tint itself and does not write a rule with a problem.
  A rule: `{ id, name, enabled, match: { class, title, initial_class, initial_title, float: ""|"yes"|"no" },
  effects: [{key, value}], glass: { mode: "inherit"|"default"|"custom"|"off", params } }`. "inherit" is not
  written; "off" writes `lucent_glass = "false"`; "custom" writes only the changed parameters; "default" is the
  default look plus the rule's own `radius`, `taps`, `corner_radius`, `opacity` (`HyprlandStore.ownKeys`).
- **Base rules** (`BaseRules`): the Lua API cannot list rules, so `~/.config/hypr/hyprland.lua` (the deployed
  file; read again whenever the page is shown) is parsed as text, comments stripped, `hl.window_rule({...})`
  read, any `lucent_glass` (a string or `table.concat`) read into parameters. They are listed read-only
  (`BaseRuleList`); **Override** starts a rule of the user's from one (`HyprlandStore.overrideOf`). A base rule
  with a name and custom glass can **follow the default look** (`HyprlandStore.follow`): the file then gets,
  before the user's rules, a rule with the same match, its own keys plus the default look, kept in the global
  `LucentGlassFollowers[<name>]` so that the on/off bind in `hyprland.lua` switches it too. The JSON keeps
  `look` (the default look it was written with); when that changes and something uses it, the file is written
  again.
- **Parameter values:** a key a rule leaves out shows the PLUGIN's default (`def`, from the Lucent README),
  dimmed. Ranges are the Theme pages' (`GlassParams`); a rule already holding a value outside its range keeps
  it in the file and shows it clamped.
- **Page actions** (`ThemeActions`): `restartBar` finds the bar from `hyprctl layers` (never `pkill -f`) and
  starts `setsid -f qs -c status-bar`; `testNotification` sends one over D-Bus. NOT run end to end.

## 5. Keyboard
`AppSettings.mode`: `"vim"` (default) or `"classic"`. **Classic** = vim keys off and type-to-search:
`KeyNav.handleClassic` types a printable key (no Ctrl/Alt/Meta; AltGr allowed; not a leading space) into the
search, Up/Down change the category, and Esc, Ctrl+C, undo, redo and Tab (only this category) run through the
same key map (`classicActions`). **Vim:** `KeyNav.handle(event)` maps a key to an action (`KeyMap`) and runs
`actions[name]`. Two panes (sidebar: j/k categories, l/Enter into the page; page: a cursor). The keys are
settings of the app (`AppDefaults.keys`, action -> list of keys; format in its comment; rebound on Settings app ›
Keyboard through `fields/KeysField`; `?` shows them). Two characters are a chord ("gg"; in fields only if quick,
400 ms). Esc: text field, page, sidebar (search first), close; `dd` then `y` deletes a window rule (the mouse ×
deletes at once).
- **Stops are duck-typed.** Any visible item with `navStop: true` (and not `navEnabled: false`) and optional
  `navAdjust(dir, big)`, `navActivate()` (may return `"delete"`, or a function = where the cursor goes next),
  `navReset()`, `navEdit()`, `navHeight`, `navFrame`. A function is also looked up on the stop's parents
  (`withFn`). `KeyNav.stops()` walks the page's (or the results') item tree, sorts by y, groups overlapping stops
  into lines, sorts a line by x; j/k keep the column (`wantX`). `Collapsible`, `SettingsRow` and the controls
  already are stops.
- **The cursor** (`NavCursor`; style `bar`, `hairline`, `corners`, `outline`) becomes a CHILD of its stop, so a
  stop must not be a positioner (Column/Row/Grid would lay it out): use an Item (`Collapsible`'s header is
  one). It hides when the mouse really moves (> 2 px) and shows on the next key.
- **Text fields** hand their keys first to `FieldKeys` (`Keys.priority: Keys.BeforeItem`,
  `Keys.onPressed: event => FieldKeys.press(event, field)`): `leaveField` (Esc, Ctrl+o, Ctrl+c, a quick "jk":
  the typed j is removed again) and Tab. A field may have `navCancel()` (keep the old value) and `navEnter()`
  (Enter stays in the field).
- **Lessons.** On Enter a Controls `TextField` emits `accepted` and the key still reaches `Keys`: leave the field
  in `onAccepted` (an Enter within 150 ms of leaving a field is ignored, `leftFieldAt`). `takeFocus()` must clear
  `focus` on every item from the field up to the view (a Loader is a FocusScope and keeps it). A list read
  through `JsonFile`'s `parsed(var)` is a Qt sequence, not a JS array: round-trip it through JSON. A function
  returned by a Repeater delegate (`navActivate`) must not look up ids after the delegate is destroyed: build it
  on a parent that stays.

## 6. Look and feel
- **Opaque or outline only.** Nothing translucent over the glass, except `FlashFrame`: the one marker every page
  uses (a soft accent area in the row's shape that fades in and out over about 1.5 s; the user asked for it).
  `gentle` scrolls only if the row is not completely in view (`SettingsPage.show`).
- **Rows:** the controls take a column of `min(340, width * 0.55)`; notes wrap up to three lines and the row
  grows. `Segmented` with `stretch` makes all segments equally wide. Sidebar: the `categoryList` ListView with a
  `ListModel` filled from the categories (roles `catId`, `name`, `icon`, `groupName`; `section`s draw the
  group headings); the host's glass reads its `currentItem` and `hoveredItem`.
- **Veil** (overlay only): `shared/glass/GlassScrim`, NOT blurred (`blurred: false`), a tint of Background at
  `Theme.scrimDim` (Panels › Settings overlay › Desktop dim; 0 = the desktop as it is). The settings panel's
  tint grows as its blur radius falls so that sharp text behind it does not show through.
- **Search** (`SettingsIndex`): all words must match; score = label (prefix 100, word start 80, substring 60) >
  synonyms > property name > section/category > note. Results replace the page while the query is not empty,
  grouped by category with the selected one first; the real controls edit in place; a jump button calls
  `jumpTo(catId, key)`. The "Only in <category>" chip (Tab) limits it. A click anywhere else in the panel takes
  the focus out of an empty search field (a `MouseArea` at z 10000 that does not accept the press).
- **Trackpad momentum:** `KineticFlickable` moves the content itself from wheel events with a `pixelDelta` and
  glides on after the fingers lift (Qt on Wayland gives none). NOT checked with a real trackpad.
- Text centred in a pill, button or chip: `shared/CenteredText` (see the root CLAUDE.md).

## 7. Testing
`./check.sh` (from `quickshell/`; lint, imports, refs, build) first. It does not show behaviour. Runtime checks:
a scratch copy of the config run with `qs -p`, scratch `XDG_CONFIG_HOME` and `HYPRLAND_SETTINGS_FILE`, a bogus
`HYPRLAND_INSTANCE_SIGNATURE` so that no reload reaches the live Hyprland, and `grim` for screenshots. **Keys:**
use a nested headless Hyprland without the plugin (Lucent's CLAUDE.md, section 6; start it with
`env -u HYPRLAND_INSTANCE_SIGNATURE`, kill the real `Hyprland` child by PID) and `wtype`/`grim` with its
`WAYLAND_DISPLAY` only, never the live display: `wtype` types into whatever has focus, and keys went into the
user's terminal twice. If no key reaches the app, the nested compositor lost the layer's keyboard focus:
restart it. Window-rule generation was checked in a nested Hyprland (later rule wins, reload re-applies to
open windows, the real plugin turned a translucent window from Hyprland's blur to the plugin's glass).
- **Checked:** pages, search and jumps, the migration of old keys, the generated Lua, vim keys and classic mode,
  the colour editor, rebinding keys, undo / redo on the Theme (see the lessons above).
- **NOT checked:** the window form's keys and mouse, a click outside the overlay, several monitors, the
  generated rules with Super+Alt+G and a follower, the Undo/Redo reveal placing the keyboard cursor, hiding
  the cursor on mouse movement, the page actions end to end, a real trackpad.

## 8. First-deploy bugs to remember
A file that uses `Theme` (or another `shared/` singleton) without `import qs.shared` gets "Theme is not defined"
at runtime while qmllint only warns: `check.sh imports` fails on it. A style with `id: look` next to a `look`
property made an unqualified `look` mean the style. The Theme file is only ever written by the settings app;
`ThemeFromSettingsApp.ownWrites` exists because a late watcher reload once overwrote newer in-memory changes.
