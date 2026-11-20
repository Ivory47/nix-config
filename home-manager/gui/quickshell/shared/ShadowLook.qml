import QtQuick

// A drop shadow in Theme (Theme.popupShadow, notificationShadow): each value is the settings app's for
// "<name>.<value>" (e.g. "popupShadow.blur" in the settings file), else ThemeDefaults[name].<value>.
QtObject {
    // "popupShadow" or "notificationShadow": the key in ThemeDefaults and the prefix in the file.
    required property string name

    readonly property var defaults: ThemeDefaults[name]

    // How dark at its darkest (0 = no shadow), how far it fades out and how far it falls below (px).
    readonly property real opacity: ThemeFromSettingsApp.real(name + ".opacity", defaults.opacity)
    readonly property real blur: ThemeFromSettingsApp.real(name + ".blur", defaults.blur)
    readonly property real offset: ThemeFromSettingsApp.real(name + ".offset", defaults.offset)
}
