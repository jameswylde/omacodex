import QtQuick
import qs.Commons
import qs.Ui
import "ChartModel.js" as Model

Column {
    id: root
    property var activity: ({})
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    readonly property color dim: Qt.darker(foreground, 1.5)
    readonly property var days: activity.days || []
    readonly property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")
    readonly property string latest: days.length ? days[days.length - 1].date : ""
    property string selectedEnd: ""
    readonly property string endDate: selectedEnd || latest || today
    readonly property var week: Model.week(days, endDate)
    readonly property string startDate: Model.shift(endDate, -6)
    spacing: Style.space(8)
    onActivityChanged: if (!activity.available) selectedEnd = ""

    function label(day) { return Qt.formatDate(new Date(day + "T12:00:00"), "d MMM") }

    Item {
        width: parent.width
        height: navigation.implicitHeight
        PanelSectionHeader {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "TOKEN HISTORY"
            foreground: root.foreground
            fontFamily: root.fontFamily
        }
        Row {
            id: navigation
            anchors.right: parent.right
            spacing: Style.space(2)
            Button {
                text: "Latest"
                fontSize: Style.font.caption
                foreground: root.dim
                visible: root.latest !== "" && root.latest < root.today
                enabled: root.endDate !== root.latest
                onClicked: root.selectedEnd = ""
            }
            Button {
                text: "Today"
                fontSize: Style.font.caption
                foreground: root.dim
                enabled: root.endDate !== root.today
                onClicked: root.selectedEnd = root.today
            }
            PanelActionButton {
                iconText: "‹"
                tooltipText: "Previous seven days"
                foreground: root.foreground
                enabled: root.days.length > 0 && root.startDate > root.days[0].date
                onClicked: root.selectedEnd = Model.shift(root.endDate, -7)
            }
            PanelActionButton {
                iconText: "›"
                tooltipText: "Next seven days"
                foreground: root.foreground
                enabled: root.endDate < root.today
                onClicked: root.selectedEnd = Model.shift(root.endDate, 7) > root.today ? root.today : Model.shift(root.endDate, 7)
            }
        }
    }
    BorderSurface {
        width: parent.width
        implicitHeight: chartContent.implicitHeight + Style.space(24)
        color: Util.alpha(root.foreground, 0.03)
        borderSpec: Border.flat(Util.alpha(root.foreground, 0.16), Style.normalBorderWidth)
        radius: Style.cornerRadius
        Column {
            id: chartContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(12)
            spacing: Style.space(10)
            Item {
                width: parent.width
                height: headline.implicitHeight
                Text {
                    id: headline
                    text: root.week.count ? Model.compact(root.week.total) + " tokens" : "No reported data"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    font.bold: true
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: headline.baseline
                    text: root.label(root.startDate) + " – " + root.label(root.endDate) + " · " + root.endDate.slice(0, 4)
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                }
            }
            Row {
                width: parent.width
                spacing: Style.space(6)
                Repeater {
                    model: root.week.rows
                    Column {
                        id: dayColumn
                        required property var modelData
                        width: (chartContent.width - Style.space(6) * 6) / 7
                        spacing: Style.space(5)
                        Text {
                            width: parent.width
                            text: Model.compact(dayColumn.modelData.tokens)
                            color: hover.containsMouse ? Color.accent : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Item {
                            width: parent.width
                            height: Style.space(95)
                            Rectangle {
                                anchors.fill: parent
                                radius: Style.cornerRadius
                                color: Util.alpha(root.foreground, 0.035)
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: dayColumn.modelData.tokens === null ? 0 : Math.max(Style.space(2), parent.height * dayColumn.modelData.tokens / Math.max(1, root.week.peak))
                                radius: Math.min(Style.cornerRadius, Style.space(4))
                                color: Util.alpha(Color.accent, hover.containsMouse ? 1 : 0.7)
                                Behavior on height { NumberAnimation { duration: 180 } }
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
                            PanelToolTip {
                                visible: hover.containsMouse
                                text: dayColumn.modelData.date + " · " + (dayColumn.modelData.tokens === null ? "Not reported" : Number(dayColumn.modelData.tokens).toLocaleString(Qt.locale(), 'f', 0) + " tokens")
                            }
                        }
                        Text {
                            width: parent.width
                            text: Qt.formatDate(new Date(dayColumn.modelData.date + "T12:00:00"), "ddd")
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
            Text {
                width: parent.width
                visible: !root.activity.available
                text: root.activity.error || "Retrieving history…"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
            }
        }
    }
    Row {
        width: parent.width
        spacing: Style.space(8)
        Repeater {
            model: [
                {label: "LIFETIME", value: Model.compact((root.activity.summary || {}).lifetimeTokens)},
                {label: "PEAK DAY", value: Model.compact((root.activity.summary || {}).peakDailyTokens)}
            ]
            StatTile {
                required property var modelData
                width: (root.width - Style.space(8)) / 2
                value: modelData.value
                label: modelData.label
                foreground: root.foreground
                fontFamily: root.fontFamily
            }
        }
    }
}
