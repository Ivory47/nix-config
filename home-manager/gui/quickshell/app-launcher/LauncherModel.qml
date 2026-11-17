import Quickshell
import QtQml

QtObject {
    id: root

    property var applications: DesktopEntries.applications

    property string searchText: ""

    property var filteredApplications: {
        if (searchText.trim() === "")
            return applications.values

        const query = searchText.toLowerCase()

        return applications.values.filter(app => {
            return app.name.toLowerCase().includes(query)
                || (app.genericName && app.genericName.toLowerCase().includes(query))
                || (app.comment && app.comment.toLowerCase().includes(query))
        })
    }

    // Opens the app the way LauncherModes says (overlay or normal window).
    function launch(app) {
        LauncherModes.launch(app)
    }
}
