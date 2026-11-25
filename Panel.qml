import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Nested panel for the sift dumps bar widget. Phase 3 reads the public sift
// history contract through HistoryStore.qml and renders the list or the
// missing/outdated/empty notice. Phase 4 adds row drag and click-to-copy.
Panel {
  id: root
  moduleName: "io.github.bethropolis.sift-dumps"
  ipcTarget: "io.github.bethropolis.sift-dumps"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // The bar tracks the widget mounted in its slot, not this nested panel.
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: root.barForeground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  property HistoryStore historyStore: HistoryStore {
    id: historyStore
  }

  readonly property bool showingList: historyStore.state === "ready"
    && historyStore.entries.length > 0
  readonly property bool showingNotice: !root.showingList
  readonly property string noticeMode: {
    if (historyStore.state === "missing") return "missing"
    if (historyStore.state === "outdated") return "outdated"
    if (historyStore.state === "loading") return "loading"
    return "empty"
  }

  property date now: new Date()
  property int focusedRow: -1
  readonly property string home: Commons.Color.home

  function open() {
    root.now = new Date()
    root.focusedRow = -1
    historyStore.active = true
    historyStore.refresh()
    root.controller.show()
  }

  function close() {
    historyStore.active = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function moveFocus(direction) {
    var content = panel.loadedContent
    var repeater = content ? content.listRepeater : null
    if (!repeater || repeater.count === 0 || direction === 0) return
    var count = repeater.count
    var next = root.focusedRow < 0
      ? (direction > 0 ? 0 : count - 1)
      : (root.focusedRow + direction + count) % count
    root.focusedRow = next
    var item = repeater.itemAt(next)
    if (!item || !item.rowItem) return
    item.rowItem.forceActiveFocus()
    root.scrollToRow(item)
  }

  function scrollToRow(item) {
    var content = panel.loadedContent
    var view = content ? content.listView : null
    if (!item || !view) return
    var top = item.y
    var bottom = top + item.height
    if (top < view.contentY) view.contentY = top
    else if (bottom > view.contentY + view.height) view.contentY = bottom - view.height
  }

  function activateFocused() {
    var content = panel.loadedContent
    var repeater = content ? content.listRepeater : null
    if (!repeater || root.focusedRow < 0) return
    var item = repeater.itemAt(root.focusedRow)
    if (item && item.rowItem) item.rowItem.activateRow()
  }

  Connections {
    target: historyStore
    function onEntriesChanged() { root.now = new Date() }
    function onStateChanged() {
      if (historyStore.state !== "ready") root.focusedRow = -1
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    padding: Style.space(12)
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.spacing.hairline)
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(440))
    // KeyboardPanel's default mask covers the whole screen for outside-click
    // dismissal. That full-screen input region also sits under an external
    // drag, so the real target never receives the drop. Keep the input region
    // on the card only; the bar icon toggles and Escape still close the panel.
    mask: Region {
      x: panel.cardOrigin.x
      y: panel.cardOrigin.y
      width: panel.contentWidth
      height: panel.contentHeight
    }

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      property alias listRepeater: listRepeater
      property alias listView: list
      implicitHeight: root.showingList
        ? header.implicitHeight + listColumn.implicitHeight + footer.height
        : noticeCard.implicitHeight

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveFocus(dy)
      }
      onTabRequested: function(direction) { root.moveFocus(direction) }
      onActivateRequested: root.activateFocused()
      onCloseRequested: root.close()

      NoticeCard {
        id: noticeCard
        anchors.fill: parent
        visible: root.showingNotice
        mode: root.noticeMode
        contentForeground: root.contentForeground
        accent: Commons.Color.accent
        fontFamily: root.contentFontFamily
      }

      Item {
        id: listContent
        anchors.fill: parent
        visible: root.showingList

        Text {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          text: "Recent dumps"
          textFormat: Text.PlainText
          bottomPadding: Style.space(8)
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.weight: Font.DemiBold
        }

        Flickable {
          id: list
          anchors.top: header.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footer.top
          contentWidth: width
          contentHeight: listColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: listColumn
            width: list.width

            Repeater {
              id: listRepeater
              model: historyStore.entries

              delegate: Column {
                id: entryGroup
                width: listColumn.width
                property alias rowItem: rowItem

                Text {
                  width: parent.width
                  visible: index === 0
                    || !historyStore.entries[index - 1]
                    || Model.groupLabel(historyStore.entries[index - 1].ts, root.now)
                      !== Model.groupLabel(modelData.ts, root.now)
                  text: Model.groupLabel(modelData.ts, root.now).toUpperCase()
                  textFormat: Text.PlainText
                  leftPadding: Style.space(12)
                  topPadding: Style.space(12)
                  bottomPadding: Style.space(6)
                  color: Util.alpha(root.contentForeground, 0.55)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: Style.font.bodySmall * 0.06
                  font.weight: Font.DemiBold
                }

                DumpRow {
                  id: rowItem
                  width: parent.width
                  entry: modelData
                  home: root.home
                  contentForeground: root.contentForeground
                  accent: Commons.Color.accent
                  fontFamily: root.contentFontFamily
                  onClicked: root.focusedRow = index
                }
              }
            }
          }
        }

        Item {
          id: footer
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: footerLabel.implicitHeight + Style.space(17)

          Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: Style.spacing.hairline
            color: Util.alpha(root.contentForeground, 0.12)
          }

          Text {
            id: footerLabel
            anchors.top: parent.top
            anchors.topMargin: Style.space(9)
            anchors.left: parent.left
            anchors.right: parent.right
            text: "Drag to attach · click to copy as file"
            textFormat: Text.PlainText
            color: Util.alpha(root.contentForeground, 0.55)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }
}
