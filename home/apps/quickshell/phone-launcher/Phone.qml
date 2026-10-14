import QtQuick
import QtQuick.Controls
import Quickshell

FocusScope {
    id: phone
    signal dismissed()
    signal launchRequested(var app)
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
        if (!results.length) return;
        grid.currentIndex = Math.max(0, Math.min(results.length - 1, grid.currentIndex + delta));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }
    function launchSelected() {
        if (grid.currentIndex >= 0 && grid.currentIndex < results.length)
            launchRequested(results[grid.currentIndex]);
    }
    Keys.onEscapePressed: dismissed()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 36
        color: phone.ink
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: 31
            color: "#f8fcfa"
            border.width: 2
            border.color: phone.mint
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
            Text {
                width: parent.width - 36
                text: "Your apps"
                color: phone.ink
                font { family: "Montserrat"; pixelSize: 23; bold: true }
            }
            ToolButton {
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
            height: 44
            focus: true
            placeholderText: "Search apps…"
            Accessible.name: "Search apps"
            color: phone.ink
            placeholderTextColor: "#618083"
            selectionColor: phone.mint
            selectedTextColor: phone.ink
            font.pixelSize: 15
            leftPadding: 15
            background: Rectangle { radius: 16; color: "white"; border.width: 2; border.color: phone.ink }
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
                width: 58; height: 58; radius: 18
                color: tile.index === grid.currentIndex ? phone.mint : (tile.index % 2 ? "#f9edf4" : "#edf7f3")
                border.color: phone.ink
                border.width: tile.index === grid.currentIndex ? 3 : 1
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
            MouseArea {
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
