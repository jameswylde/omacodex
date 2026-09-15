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
        contentWidth: fittedContentWidth(Style.space(350))
        contentHeight: fittedContentHeight(content.implicitHeight + footer.implicitHeight + Style.space(16), Style.space(670))
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
            Flickable {
                id: scroller
                anchors.top: parent.top
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
                        meta: root.snapshot.plan ? root.snapshot.plan.replace(/_/g, " ") : "ChatGPT account"
                        iconComponent: Component {
                            Logo { width: Style.space(38); height: width; source: Qt.resolvedUrl("assets/codex.svg"); color: Color.foreground }
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
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: root.snapshot.rows || []
                        UsageRow { required property var modelData; width: content.width; entry: modelData; nowMs: root.nowMs }
                    }
                    PanelSeparator { width: parent.width }
                    PanelSectionHeader { text: "CREDITS" }
                    Repeater {
                        model: root.snapshot.credits || [{title: "Credits", value: "Not reported"}]
                        Text {
                            required property var modelData
                            width: content.width
                            textFormat: Text.PlainText
                            text: modelData.title + "  ·  " + modelData.value
                            color: Color.foreground
                            font.family: Style.font.family
                            font.pixelSize: Style.font.body
                            wrapMode: Text.Wrap
                        }
                    }
                    Text {
                        visible: root.snapshot.resetCredits !== null && root.snapshot.resetCredits !== undefined
                        text: "Earned resets  ·  " + (root.snapshot.resetCredits || 0)
                        color: Color.foreground
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
            Item {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: Math.max(updated.implicitHeight, syncButton.implicitHeight)
                height: implicitHeight
                Text {
                    id: updated
                    anchors.left: parent.left
                    anchors.right: syncButton.left
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lastUpdatedAt ? "Last update\n" + Qt.formatDateTime(new Date(root.lastUpdatedAt * 1000), "d MMM, HH:mm:ss") : "Last update\nNot synced"
                    color: Color.foreground
                    opacity: 0.65
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }
                Button {
                    id: syncButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.syncing ? "Syncing…" : "Sync"
                    iconText: "󰑓"
                    iconSpinning: root.syncing
                    enabled: !root.syncing
                    bordered: true
                    tooltipText: "Refresh usage (R)"
                    onClicked: root.refresh()
                }
            }
        }
    }
}
