import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
    id: root
    property string value: ""
    property string label: ""
    property bool hot: false
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    readonly property color tone: hot ? Color.accent : foreground
    implicitHeight: tileColumn.implicitHeight + Style.space(16)
    color: Util.alpha(tone, hot ? 0.07 : 0.03)
    borderSpec: Border.flat(Util.alpha(tone, hot ? 0.4 : 0.16), Style.normalBorderWidth)
    radius: Style.cornerRadius

    Column {
        id: tileColumn
        anchors.centerIn: parent
        width: parent.width - Style.space(8)
        spacing: Style.space(2)
        Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.value
            color: root.tone
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.label
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
    HoverHandler { id: hover }
    PanelToolTip {
        visible: hover.hovered
        text: root.label + " · " + root.value
        fontFamily: root.fontFamily
    }
}
