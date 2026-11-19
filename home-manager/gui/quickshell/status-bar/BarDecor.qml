import QtQuick
import QtQuick.Shapes
import qs.shared

// What the full-width bar draws itself when it has a cut-out (the place the indicator docks into): the
// panel fill (only without compositor glass, which has its own hole), the outline of the cut-out and
// the line along the bar's bottom edge, which stops where the cut-out opens to it. Put it in the bar's
// content (which clips to the bar). `cut` is the cut-out's rectangle in the bar's pixels with its
// corner radius `r`; it may reach below the bar ("bite") or lie inside it ("pocket"). Without a cut-out
// (`cut` empty) it is the plain bar: a fill and a line.
Item {
    id: root

    property rect cut: Qt.rect(0, 0, 0, 0)
    property real r: 0
    property bool glassWanted: true

    anchors.fill: parent

    readonly property bool has: cut.width > 1 && cut.height > 1 && r > 0
    readonly property bool bite: has && cut.y + cut.height > height - 0.5
    // Where the rounded cut-out's corners meet the bottom edge (a shallow bite: before its straight sides).
    readonly property real dy: Math.max(0, cut.y + r - height)
    readonly property real dx: Math.sqrt(Math.max(0, r * r - dy * dy))
    readonly property real xl: bite ? (dy > 0 ? cut.x + r - dx : cut.x) : width
    readonly property real xr: bite ? (dy > 0 ? cut.x + cut.width - r + dx : cut.x + cut.width) : width

    readonly property color lineColor: Qt.alpha(Theme.barBorderColor, Theme.barBorderOpacity)

    // The fill, with the cut-out as a second outline (odd-even).
    Shape {
        anchors.fill: parent
        visible: !root.glassWanted
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.background
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            PathMove { x: root.cut.x + root.r; y: root.cut.y }
            PathLine { x: root.cut.x + root.cut.width - root.r; y: root.cut.y }
            PathArc { x: root.cut.x + root.cut.width; y: root.cut.y + root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
            PathLine { x: root.cut.x + root.cut.width; y: root.cut.y + root.cut.height - root.r }
            PathArc { x: root.cut.x + root.cut.width - root.r; y: root.cut.y + root.cut.height; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
            PathLine { x: root.cut.x + root.r; y: root.cut.y + root.cut.height }
            PathArc { x: root.cut.x; y: root.cut.y + root.cut.height - root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
            PathLine { x: root.cut.x; y: root.cut.y + root.r }
            PathArc { x: root.cut.x + root.r; y: root.cut.y; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
        }
    }

    // The outline of the cut-out (the part outside the bar is clipped away by the bar).
    Shape {
        anchors.fill: parent
        visible: root.has
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.lineColor
            strokeWidth: 1
            startX: root.cut.x + root.r
            startY: root.cut.y
            PathLine { x: root.cut.x + root.cut.width - root.r; y: root.cut.y }
            PathArc { x: root.cut.x + root.cut.width; y: root.cut.y + root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
            PathLine { x: root.cut.x + root.cut.width; y: root.cut.y + root.cut.height - root.r }
            PathArc { x: root.cut.x + root.cut.width - root.r; y: root.cut.y + root.cut.height; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
            PathLine { x: root.cut.x + root.r; y: root.cut.y + root.cut.height }
            PathArc { x: root.cut.x; y: root.cut.y + root.cut.height - root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
            PathLine { x: root.cut.x; y: root.cut.y + root.r }
            PathArc { x: root.cut.x + root.r; y: root.cut.y; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
        }
    }

    // The line along the bottom edge: in two pieces where a bite opens to it.
    Rectangle {
        x: 0
        y: root.height - 1
        width: root.xl
        height: 1
        color: root.lineColor
    }
    Rectangle {
        x: root.xr
        y: root.height - 1
        width: root.width - root.xr
        height: 1
        color: root.lineColor
    }
}
