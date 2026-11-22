import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Centered replacement for the list when there is nothing to show. The
// install command is displayed and copied only; the plugin never executes it.
Item {
  id: root

  property string mode: "missing"
  property color contentForeground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  // Verified 2026-11-22 against AUR sift-context-bin 1.9.0-1, which includes
  // `sift history`. The plugin displays and copies this command only.
  property string installCommand: "yay -S sift-context-bin"
  property bool copied: false

  readonly property bool loading: root.mode === "loading"
  readonly property bool empty: root.mode === "empty"
  readonly property bool showCommand: !root.empty && !root.loading
  readonly property string title: root.loading
    ? "Loading dumps…"
    : (root.empty
      ? "No dumps yet"
      : (root.mode === "outdated" ? "sift needs updating" : "sift isn't installed"))
  readonly property string body: root.loading
    ? ""
    : (root.empty
      ? "Run a dump in any project and it will show up here."
      : "Install it to see your recent dumps here.")
  readonly property color dimForeground: Util.alpha(root.contentForeground, 0.58)

  function copyCommand() {
    if (copyProc.running) return
    root.copied = false
    copyProc.running = true
    copyTimer.restart()
  }

  implicitWidth: Style.space(320)
  implicitHeight: contentColumn.implicitHeight + Style.space(64)

  property Process copyProc: Process {
    // The command is passed as argv, never interpolated into shell source.
    command: [
      "/usr/bin/sh", "-c",
      'printf "%s" "$1" | /usr/bin/wl-copy --type text/plain',
      "sift-dumps-copy", root.installCommand
    ]
    onExited: function(exitCode, exitStatus) {
      copyTimer.stop()
      if (exitCode === 0 && exitStatus === 0) {
        root.copied = true
        copiedTimer.restart()
      }
    }
  }

  property Timer copyTimer: Timer {
    interval: 2500
    repeat: false
    onTriggered: if (copyProc.running) copyProc.running = false
  }

  property Timer copiedTimer: Timer {
    interval: 1600
    repeat: false
    onTriggered: root.copied = false
  }

  Column {
    id: contentColumn
    width: Math.max(Style.space(240), Math.min(
      root.width > 0 ? root.width : Style.space(320),
      Style.space(320)))
    anchors.centerIn: parent
    spacing: Style.space(10)

    Item {
      width: parent.width
      height: Style.space(12)

      Item {
        id: logo
        width: Style.space(24)
        height: Style.space(12)
        anchors.centerIn: parent

        readonly property real barWidth: width * 0.7
        readonly property real barHeight: height * 0.3
        readonly property color logoColor: Util.alpha(root.contentForeground, 0.38)

        Rectangle {
          x: 0
          y: 0
          width: logo.barWidth
          height: logo.barHeight
          radius: height / 2
          color: logo.logoColor
        }

        Rectangle {
          x: logo.width * 0.3
          y: logo.height * 0.7
          width: logo.barWidth
          height: logo.barHeight
          radius: height / 2
          color: logo.logoColor
        }
      }
    }

    Text {
      width: parent.width
      text: root.title
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      color: root.contentForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.weight: Font.DemiBold
    }

    Text {
      width: parent.width
      visible: !root.loading
      text: root.body
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: root.dimForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    Item {
      width: parent.width
      height: Style.space(2)
      visible: root.showCommand
    }

    Rectangle {
      width: parent.width
      height: Style.space(38)
      visible: root.showCommand
      radius: Style.space(8)
      color: Style.normalFillFor(root.contentForeground, root.accent)
      border.width: Style.normalBorderWidth
      border.color: Style.normalBorderFor(root.contentForeground, root.accent)

      Text {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.right: copyButton.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: "$ " + root.installCommand
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.contentForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      Button {
        id: copyButton
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        text: root.copied ? "Copied" : "Copy"
        bordered: true
        focusable: false
        foreground: root.contentForeground
        accent: root.accent
        fontFamily: root.fontFamily
        fontSize: Style.font.bodySmall
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(3)
        onClicked: root.copyCommand()
      }
    }
  }
}
