import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar entry point for sift dumps. The bar item is the two-bar sift mark and
// nothing else; the recent-dump list lives in the nested Panel.qml.
BarWidget {
  id: root
  moduleName: "io.github.bethropolis.sift-dumps"

  // ---- Nested panel lifecycle. The shell routes summon/hide to the
  //      bar-widget root, which forwards to the loaded panel. Keep the same
  //      shape as the installed clock widget.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  ShellIpc {
    target: "io.github.bethropolis.sift-dumps"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: Style.bar.iconSlot
    tooltipText: "sift dumps"

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }

    // The sift mark on a 512 x 512 design grid: two staggered horizontal
    // bars with fully rounded ends. Drawn here as two rectangles so it
    // follows the bar foreground color instead of shipping a raster logo.
    Item {
      id: logo
      width: Style.bar.iconCanvas
      height: Math.round(Style.bar.iconCanvas * 0.5)
      anchors.centerIn: parent

      readonly property real barWidth: width * 0.7
      readonly property real barHeight: height * 0.3
      readonly property color barColor: button.active && button.useActiveColor
        ? button.activeColor
        : button.foreground

      Rectangle {
        x: 0
        y: 0
        width: logo.barWidth
        height: logo.barHeight
        radius: height / 2
        color: logo.barColor
      }

      Rectangle {
        x: logo.width * 0.3
        y: logo.height * 0.7
        width: logo.barWidth
        height: logo.barHeight
        radius: height / 2
        color: logo.barColor
      }
    }
  }
}
