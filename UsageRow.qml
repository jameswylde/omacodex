import QtQuick
import qs.Commons

Column {
    id: root
    required property var entry
    property double nowMs: Date.now()
    readonly property bool known: entry.usedPercent !== null && entry.usedPercent !== undefined
    spacing: Style.space(6)
    Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.entry.title
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        wrapMode: Text.Wrap
    }
    Rectangle {
        width: parent.width
        height: Style.space(6)
        radius: height / 2
        color: Style.selectedFillFor(Color.foreground, Color.accent)
        Rectangle {
            height: parent.height
            width: root.known ? parent.width * root.entry.usedPercent / 100 : 0
            radius: parent.radius
            color: root.entry.usedPercent >= 90 ? Color.urgent : Color.accent
            Behavior on width { NumberAnimation { duration: 180 } }
        }
    }
    Text {
        width: parent.width
        textFormat: Text.PlainText
        text: (root.known ? root.entry.usedPercent + "% used · " : "") + root.entry.detail
        color: Color.foreground
        opacity: 0.65
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
    Text {
        width: parent.width
        visible: !!root.entry.resetsAt
        textFormat: Text.PlainText
        text: {
            if (!root.entry.resetsAt) return ""
            if (root.entry.resetsAt * 1000 <= root.nowMs) return "Reset due · sync to update"
            return "Resets " + Qt.formatDateTime(new Date(root.entry.resetsAt * 1000), "ddd d MMM, HH:mm")
        }
        color: Color.foreground
        opacity: 0.65
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
}
