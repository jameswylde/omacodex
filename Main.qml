import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "omacodex.usage"
    ipcTarget: "omacodex.usage"
    manageIpc: false
    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.5)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    property var snapshot: ({})
    property string errorText: ""
    property double nowMs: Date.now()
    property double lastUpdatedAt: 0
    property bool received: false
    readonly property bool syncing: probe.running

    function refresh() {
        if (!probe.running) {
            received = false
            probe.running = true
        }
    }
    onOpenedChanged: if (opened) {
        nowMs = Date.now()
        if (!snapshot.updatedAt || nowMs / 1000 - snapshot.updatedAt > 60) refresh()
    }
    Process {
        id: probe
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("usage.py").toString().replace(/^file:\/\//, ""))]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    root.received = true
                    if (data.ok) {
                        root.snapshot = data
                        root.lastUpdatedAt = data.updatedAt
                        root.errorText = ""
                    } else {
                        // Avoid displaying a previous account's quota after login changes.
                        root.snapshot = ({})
                        root.errorText = data.error || "Usage unavailable. Try syncing again."
                    }
                } catch (e) {
                    root.snapshot = ({})
                    root.errorText = "Could not read usage. Try syncing again."
                }
            }
        }
        onExited: {
            if (!root.received) {
                root.snapshot = ({})
                root.errorText = "Usage helper failed. Check Python 3 and Codex are installed."
            }
        }
    }
    Timer {
        interval: Math.max(60, Math.min(3600, Number(root.setting("refreshIntervalSec", 300)) || 300)) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 30000
        running: root.opened
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        tooltipText: "Codex usage"
        // SVG artwork fills its canvas; font glyphs leave internal whitespace.
        // Match their visible size while retaining the standard icon slot.
        opticalSize: Style.bar.iconFont * 0.85
        iconComponent: Component {
            Logo { source: Qt.resolvedUrl("assets/chatgpt.svg"); color: button.foreground }
        }
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.MiddleButton) root.refresh()
            else root.toggle()
        }
    }
    KeyboardPanel {
        id: popup
        objectName: "codexPopup"
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keys
        contentWidth: fittedContentWidth(Style.space(440))
        contentHeight: fittedContentHeight(content.implicitHeight + footer.implicitHeight + header.height
                                          + scroller.anchors.topMargin + scroller.anchors.bottomMargin, Style.space(760))
        PanelKeyCatcher {
            id: keys
            anchors.fill: parent
            onCloseRequested: root.close()
            onActivateRequested: root.refresh()
            onTextKey: function(text) { if (text.toLowerCase() === "r") root.refresh() }
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onMoveRequested: function(dx, dy) {
                scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY + dy * Style.space(48)))
            }
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.max(heading.implicitHeight, refreshButton.implicitHeight)
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)
                    PanelSectionHeader {
                        id: heading
                        text: "CODEX"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    BorderSurface {
                        implicitWidth: plan.implicitWidth + Style.space(10)
                        implicitHeight: plan.implicitHeight + Style.space(4)
                        color: Util.alpha(root.dim, 0.1)
                        borderSpec: Border.flat(Util.alpha(root.dim, 0.45), Style.normalBorderWidth)
                        radius: Style.cornerRadius
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: plan
                            anchors.centerIn: parent
                            text: root.snapshot.plan || "ChatGPT"
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                        }
                    }
                }
                PanelActionButton {
                    id: refreshButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "󰑐"
                    tooltipText: "Sync usage and history  (r)"
                    foreground: root.syncing ? Color.accent : root.foreground
                    fontFamily: root.fontFamily
                    enabled: !root.syncing
                    onClicked: root.refresh()
                    RotationAnimation on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: root.syncing
                    }
                    onRotationChanged: if (!root.syncing && rotation !== 0) rotation = 0
                }
            }
            Flickable {
                id: scroller
                anchors.top: header.bottom
                anchors.topMargin: Style.space(10)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: footer.top
                anchors.bottomMargin: Style.space(16)
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                Column {
                    id: content
                    width: scroller.width
                    spacing: Style.space(12)
                    PanelHero {
                        title: "Codex"
                        meta: "Usage & activity"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                        iconComponent: Component {
                            Item {
                                implicitWidth: Style.space(44)
                                implicitHeight: Style.space(44)
                                BorderSurface {
                                    anchors.fill: parent
                                    color: Util.alpha(Color.accent, 0.10)
                                    borderSpec: Border.flat(Util.alpha(Color.accent, 0.45), Style.normalBorderWidth)
                                    radius: Style.cornerRadius
                                }
                                Logo {
                                    anchors.centerIn: parent
                                    width: Style.space(26); height: width
                                    source: Qt.resolvedUrl("assets/codex.svg")
                                    color: Color.accent
                                }
                            }
                        }
                    }
                    PanelSeparator { width: parent.width }
                    PanelSectionHeader { text: "USAGE" }
                    Text {
                        width: parent.width
                        visible: !root.snapshot.ok
                        textFormat: Text.PlainText
                        text: root.errorText || "Retrieving usage…"
                        color: root.errorText ? Color.urgent : Color.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: root.snapshot.rows || []
                        UsageRow { required property var modelData; width: content.width; entry: modelData; nowMs: root.nowMs }
                    }
                    PanelSeparator { width: parent.width }
                    TokenChart {
                        width: parent.width
                        activity: root.snapshot.activity || ({})
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                    }
                    Grid {
                        id: creditTiles
                        width: parent.width
                        columns: 2
                        spacing: Style.space(8)
                        Repeater {
                            model: root.snapshot.credits || [{title: "Credits", value: "Not reported"}]
                            StatTile {
                                required property var modelData
                                width: (creditTiles.width - creditTiles.spacing) / 2
                                value: modelData.value
                                label: modelData.title.toUpperCase()
                                hot: Number(modelData.value) > 0 || modelData.value === "Unlimited" || modelData.value.indexOf("Available") === 0
                                foreground: root.foreground
                                fontFamily: root.fontFamily
                            }
                        }
                        StatTile {
                            width: (creditTiles.width - creditTiles.spacing) / 2
                            value: root.snapshot.resetCredits === null || root.snapshot.resetCredits === undefined ? "–" : String(root.snapshot.resetCredits)
                            label: "EARNED RESETS"
                            hot: Number(root.snapshot.resetCredits) > 0
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                        }
                    }
                }
            }
            Item {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: updated.implicitHeight + Style.space(8)
                height: implicitHeight
                Text {
                    id: updated
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lastUpdatedAt ? "Updated " + Qt.formatDateTime(new Date(root.lastUpdatedAt * 1000), "d MMM, HH:mm:ss") : "Not synced"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }

            }
        }
    }
}
