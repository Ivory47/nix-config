import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.shared
import qs.shared.glass

// The app launcher: the model, the rows and what Enter and Tab do. The panel, search, keys, glass and
// opening and closing are GlassSearchPopup's (and GlassPopup's); see there.
GlassSearchPopup {
    id: root
    WlrLayershell.namespace: "app-launcher"

    ipcTarget: "launcher"
    placeholder: "Search applications..."
    panelWidth: 600
    panelHeight: 400

    model: launcherModel.filteredApplications

    delegate: LauncherItem {
        required property var modelData

        app: modelData
        width: ListView.view.width
        onActivated: {
            LauncherModes.launch(app)
            root.closePopup()
        }
    }

    onAccepted: index => {
        launcherModel.launch(launcherModel.filteredApplications[index])
        root.closePopup()
    }

    // Tab: for an app that can be opened as an overlay or as a normal window, switch which.
    onKeyPressed: event => {
        if (event.key === Qt.Key_Tab) {
            if (list.currentIndex >= 0 && list.currentIndex < list.count)
                LauncherModes.toggle(launcherModel.filteredApplications[list.currentIndex])
            event.accepted = true
        } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
            root.closePopup()
            event.accepted = true
        }
    }

    LauncherModel {
        id: launcherModel
        searchText: root.searchText
    }

    Connections {
        target: launcherModel

        function onFilteredApplicationsChanged() {
            list.currentIndex = launcherModel.filteredApplications.length > 0 ? 0 : -1
        }
    }
}
