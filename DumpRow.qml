import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// One recent dump. The archive URI is offered as text/uri-list only: a click
// copies it, and a pointer drag past 10 px starts an external drag. The plugin
// never reads the archive contents.
Rectangle {
  id: root

  property var entry: ({})
  property string home: ""
  property color contentForeground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property bool dragging: false
  property bool dragOccurred: false

  signal clicked()

  readonly property string projectName: root.entry && root.entry.name
    ? String(root.entry.name)
    : ""
  readonly property string projectPath: Model.displayPath(
    root.entry && root.entry.root ? root.entry.root : "",
    root.home)
  readonly property string tokenText: Model.formatTokens(root.entry ? root.entry.tokens : 0)
  readonly property string byteText: Model.formatBytes(root.entry ? root.entry.bytes : 0)
  // sift history --json only lists entries whose archive exists; an empty
  // path disables both actions rather than offering a missing file.
  readonly property string fileUri: Model.fileUri(
    root.entry && root.entry.file ? root.entry.file : "")
  readonly property color dimForeground: Util.alpha(root.contentForeground, 0.58)
  readonly property bool hot: mouse.containsMouse

  function copyUri() {
    if (root.fileUri === "" || copyProc.running) return
    copyProc.running = true
    copyTimer.restart()
  }

  function beginDrag() {
    if (root.fileUri === "" || root.dragging) return
    root.dragging = true
    root.dragOccurred = true
    root.Drag.active = true
    root.Drag.startDrag(Qt.CopyAction)
    if (root.Drag.active) root.Drag.active = false
    root.dragging = false
  }

  // Qt 6.12: Drag.Automatic both starts on active and double-starts with the
  // explicit call below. Drag.None + startDrag gives exactly one session, and
  // startDrag still uses mimeData. This was verified against a browser drop
  // zone; text/uri-list arrives as a file.
  Drag.dragType: Drag.None
  Drag.supportedActions: Qt.CopyAction
  Drag.proposedAction: Qt.CopyAction
  Drag.mimeData: ({ "text/uri-list": root.fileUri + "\r\n" })
  Drag.hotSpot.x: root.width / 2
  Drag.hotSpot.y: root.height / 2
  Drag.onDragStarted: {
    root.dragging = true
    console.log("sift-dumps: drag started")
  }
  Drag.onDragFinished: function(dropAction) {
    root.dragging = false
    console.log("sift-dumps: drag finished action=" + dropAction)
    // The drop action is deliberately ignored; Phase 4 records behaviour.
  }

  implicitHeight: Style.space(56)
  radius: Style.space(10)
  activeFocusOnTab: true
  color: root.dragging
    ? Style.selectedFillFor(root.contentForeground, root.accent)
    : (root.activeFocus
      ? Style.focusFillFor(root.contentForeground, root.accent)
      : (root.hot ? Style.hoverFillFor(root.contentForeground, root.accent) : "transparent"))
  border.width: root.dragging
    ? Math.max(1, Style.space(1))
    : (root.activeFocus
      ? Style.focusBorderWidth
      : (root.hot ? Style.hoverBorderWidth : 0))
  border.color: root.dragging
    ? root.accent
    : (root.activeFocus
      ? Style.focusBorderFor(root.contentForeground, root.accent)
      : (root.hot ? Style.hoverBorderFor(root.contentForeground, root.accent) : "transparent"))

  layer.enabled: root.dragging
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 1)
    shadowOpacity: 0.35
    shadowBlur: 0.4
    shadowVerticalOffset: Math.max(1, Style.space(2))
  }

  Behavior on color {
    ColorAnimation { duration: Style.duration(120) }
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.topMargin: Style.space(10)
    anchors.bottomMargin: Style.space(10)
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)

    Rectangle {
      id: tile
      width: Style.space(36)
      height: width
      radius: Style.space(8)
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      color: Style.normalFillFor(root.contentForeground, root.accent)

      Text {
        anchors.centerIn: parent
        text: "󰉋"
        textFormat: Text.PlainText
        color: root.dragging || root.activeFocus ? root.accent : root.dimForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.iconLarge
      }
    }

    Column {
      id: metaColumn
      width: Math.max(Style.space(48), tokenLabel.implicitWidth, byteLabel.implicitWidth)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        id: tokenLabel
        width: parent.width
        text: root.tokenText
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignRight
        color: root.contentForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        id: byteLabel
        width: parent.width
        text: root.byteText
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignRight
        color: root.dimForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Column {
      anchors.left: tile.right
      anchors.leftMargin: Style.space(12)
      anchors.right: metaColumn.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: root.projectName
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.contentForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.weight: Font.DemiBold
      }

      Text {
        width: parent.width
        text: root.projectPath
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: root.dimForeground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    preventStealing: true
    property point pressPoint: Qt.point(0, 0)

    onPressed: function(event) {
      root.forceActiveFocus()
      pressPoint = Qt.point(event.x, event.y)
      root.dragOccurred = false
      root.dragging = false
    }

    onPositionChanged: function(event) {
      if (!pressed || root.dragging) return
      var dx = event.x - pressPoint.x
      var dy = event.y - pressPoint.y
      if (dx * dx + dy * dy >= 100) root.beginDrag()
    }

    onClicked: {
      if (root.dragOccurred) return
      root.forceActiveFocus()
      root.clicked()
      root.copyUri()
    }

    onCanceled: {
      root.dragging = false
      root.dragOccurred = true
    }
  }

  Process {
    id: copyProc
    command: [
      "/usr/bin/sh", "-c",
      'printf "%s\\r\\n" "$1" | /usr/bin/wl-copy --type text/uri-list',
      "sift-dumps-copy", root.fileUri
    ]
    onExited: copyTimer.stop()
  }

  Timer {
    id: copyTimer
    interval: 2500
    repeat: false
    onTriggered: if (copyProc.running) copyProc.running = false
  }

  function activateRow() {
    root.clicked()
    root.copyUri()
  }

  Keys.onReturnPressed: root.activateRow()
  Keys.onEnterPressed: root.activateRow()
  Keys.onSpacePressed: root.activateRow()
}
