import QtQuick
import QtQuick.Controls
import Quickshell

FocusScope {
    id: phone
    signal dismissed()
    signal launchRequested(var app)
    property bool depth: true
    property bool interactive: true
    property alias query: search.text
    readonly property var results: DesktopEntries.applications.values.filter(app => {
        const terms = search.text.trim().toLowerCase().split(/\s+/);
        const haystack = [app.name, app.genericName, ...(app.keywords ?? [])].join(" ").toLowerCase();
        return !app.noDisplay && terms.every(term => haystack.includes(term));
    }).sort((a, b) => a.name.localeCompare(b.name));
    readonly property color ink: "#28585c"
    readonly property color mint: "#b8ece6"
    readonly property color pink: "#f5dbe9"
    focus: true
    onResultsChanged: grid.currentIndex = results.length ? 0 : -1

    function moveSelection(delta) {
        if (!interactive || !results.length) return;
        grid.currentIndex = Math.max(0, Math.min(results.length - 1, grid.currentIndex + delta));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }
    function launchSelected() {
        if (interactive && grid.currentIndex >= 0 && grid.currentIndex < results.length)
            launchRequested(results[grid.currentIndex]);
    }
    Keys.onEscapePressed: dismissed()

    // Layered low-opacity silhouettes soften the shadow without a blur pass.
    Repeater {
        model: phone.depth ? 7 : 0
        Rectangle {
            required property int index
            x: 10 - index * 2
            y: 15 - index * 2
            width: phone.width - 4 + index * 4
            height: phone.height - 8 + index * 4
            radius: 37 + index * 2
            color: "#183b42"
            opacity: 0.025
        }
    }
    // The offset rear shell and stepped rim expose a restrained side wall.
    Rectangle {
        visible: phone.depth
        x: 28; y: 17
        width: phone.width - 12; height: phone.height - 12
        radius: 36
        color: "#183d43"
        border.color: "#123139"
        border.width: 1
        Rectangle {
            x: parent.width - 3; y: 120
            width: 3; height: 45; radius: 1.5
            color: "#658d8e"
        }
    }
    Rectangle {
        visible: phone.depth
        x: 17; y: 11
        width: phone.width - 12; height: phone.height - 12
        radius: 36
        color: "#32686d"
        border.color: "#91b4b3"
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 36
        color: phone.ink
        border.width: phone.depth ? 1 : 0
        border.color: "#b7d9d4"
        Rectangle {
            anchors.fill: parent
            anchors.margins: phone.depth ? 6 : 5
            radius: 31
            gradient: Gradient {
                GradientStop { position: 0; color: "#e2f6f0" }
                GradientStop { position: 0.35; color: "#fbfcfa" }
                GradientStop { position: 1; color: "#e9f5f2" }
            }
            border.width: 2
            border.color: phone.depth ? "#86b8b2" : phone.mint
        }
        Rectangle {
            width: 92; height: 17; radius: 9
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            color: phone.ink
        }
    }

    Column {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 43; leftMargin: 25; rightMargin: 25 }
        spacing: 14
        Row {
            width: parent.width
            Column {
                width: parent.width - 36
                spacing: 2
                Text {
                    text: "APPLICATIONS  /  " + phone.results.length
                    color: "#648f91"
                    font { family: "Montserrat"; pixelSize: 9; bold: true; letterSpacing: 1.4 }
                }
                Text {
                    text: "Your apps"
                    color: phone.ink
                    font { family: "Montserrat"; pixelSize: 25; bold: true; italic: true }
                }
                Row {
                    spacing: 3
                    Repeater {
                        model: ["#72c9c1", "#b7a7d8", "#e7b5cf", "#e6d891"]
                        Rectangle { required property color modelData; width: 17; height: 3; radius: 1; color: modelData }
                    }
                }
            }
            ToolButton {
                enabled: phone.interactive
                width: 32; height: 32
                text: "×"
                Accessible.name: "Close launcher"
                onClicked: phone.dismissed()
                contentItem: Text { text: parent.text; color: phone.ink; font.pixelSize: 25; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 12; color: parent.hovered ? phone.pink : "#e9f6f2"; border.color: phone.ink }
            }
        }
        TextField {
            id: search
            objectName: "search"
            width: parent.width
            height: 40
            focus: true
            readOnly: !phone.interactive
            placeholderText: "Search apps…"
            Accessible.name: "Search apps"
            color: phone.ink
            placeholderTextColor: "#618083"
            selectionColor: phone.mint
            selectedTextColor: phone.ink
            font.pixelSize: 15
            leftPadding: 15
            background: Rectangle { radius: 20; color: "#f9ffff"; border.width: 2; border.color: phone.ink }
            Keys.onDownPressed: phone.moveSelection(grid.columns)
            Keys.onUpPressed: phone.moveSelection(-grid.columns)
            // Leave left/right available for editing the search text.
            Keys.onTabPressed: phone.moveSelection(1)
            Keys.onBacktabPressed: phone.moveSelection(-1)
            Keys.onReturnPressed: phone.launchSelected()
            Keys.onEnterPressed: phone.launchSelected()
            Keys.onEscapePressed: phone.dismissed()
            Component.onCompleted: forceActiveFocus()
        }
    }

    GridView {
        id: grid
        objectName: "apps"
        anchors { top: header.bottom; bottom: footer.top; left: parent.left; right: parent.right; topMargin: 17; bottomMargin: 12; leftMargin: 22; rightMargin: 22 }
        readonly property int columns: width < 300 ? 3 : 4
        cellWidth: width / columns
        cellHeight: 104
        clip: true
        model: phone.results
        currentIndex: count ? 0 : -1
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight
            Rectangle {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                width: 58; height: 58; radius: 20
                color: tile.index === grid.currentIndex ? phone.mint : (tile.index % 2 ? "#f9edf4" : "#edf7f3")
                border.color: phone.ink
                border.width: 2
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 16
                    color: "transparent"
                    border.width: 1
                    border.color: tile.index === grid.currentIndex ? "#faffff" : "#c4ded9"
                }
                Behavior on color { ColorAnimation { duration: 100 } }
                Image {
                    id: icon
                    anchors.centerIn: parent
                    width: 34; height: 34
                    source: tile.modelData.icon ? Quickshell.iconPath(tile.modelData.icon, true) : ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize { width: 48; height: 48 }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !icon.source.toString() || icon.status === Image.Error
                    text: tile.modelData.name.slice(0, 1).toUpperCase()
                    font { pixelSize: 25; bold: true }
                    color: phone.ink
                }
            }
            Text {
                anchors { top: parent.top; topMargin: 64; left: parent.left; right: parent.right; leftMargin: 3; rightMargin: 3 }
                text: tile.modelData.name
                color: phone.ink
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: 3 }
                text: String(tile.index + 1).padStart(2, "0")
                color: "#719f9f"
                font { pixelSize: 9; bold: true }
            }
            MouseArea {
                enabled: phone.interactive
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: grid.currentIndex = tile.index
                onClicked: phone.launchRequested(tile.modelData)
            }
        }
        Text {
            anchors.centerIn: parent
            visible: grid.count === 0
            text: "No apps found\nTry another name."
            color: "#618083"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 15
        }
    }
    Column {
        id: footer
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 24 }
        spacing: 13
        Text {
            text: "↑ ↓ rows  ·  Tab next  ·  Enter open  ·  Esc close"
            color: "#618083"
            font.pixelSize: 10
        }
        Rectangle { width: 78; height: 4; radius: 2; color: phone.ink; anchors.horizontalCenter: parent.horizontalCenter }
    }
}
