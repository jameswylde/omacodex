import QtQuick
import QtQuick.Effects

Item {
    id: root
    property url source
    property color color: "white"
    Image {
        id: original
        anchors.fill: parent
        source: root.source
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        visible: false
    }
    MultiEffect {
        anchors.fill: original
        source: original
        colorization: 1
        colorizationColor: root.color
    }
}
