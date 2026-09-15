import QtQuick
import qs.Commons

Column {
    id: root
    required property var entry
    property double nowMs: Date.now()
    readonly property bool known: entry.usedPercent !== null && entry.usedPercent !== undefined
    readonly property real remaining: known ? Math.max(0, Math.min(100, 100 - entry.usedPercent)) : 0
    spacing: Style.space(4)
    Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.entry.title
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        wrapMode: Text.Wrap
    }
    Rectangle {
        visible: root.known
        width: parent.width
        height: Style.space(4)
        radius: height / 2
        color: Style.selectedFillFor(Color.foreground, Color.accent)
        Rectangle {
            height: parent.height
            width: parent.width * root.remaining / 100
            radius: parent.radius
            color: root.remaining <= 10 ? Color.urgent : Color.accent
            Behavior on width { NumberAnimation { duration: 180 } }
        }
    }
    Item {
        width: parent.width
        visible: root.known
        height: Math.max(percentage.implicitHeight, reset.implicitHeight)
        Text {
            id: percentage
            anchors.left: parent.left
            text: root.remaining + "% left"
            color: Qt.darker(Color.foreground, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        Text {
            id: reset
            anchors.right: parent.right
            text: root.entry.resetsAt ? Qt.formatDateTime(new Date(root.entry.resetsAt * 1000), "dd/MM/yyyy HH:mm") : ""
            color: Qt.darker(Color.foreground, 1.5)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
    }
    Text {
        visible: !root.known
        width: parent.width
        textFormat: Text.PlainText
        text: root.entry.detail
        color: Qt.darker(Color.foreground, 1.5)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
}
