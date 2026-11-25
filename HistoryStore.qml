import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Locates sift, reads the public history contract and exposes the states the
// panel needs. The plugin never reads history.jsonl itself and never runs a
// command that writes a dump.
QtObject {
  id: root

  property string state: "loading"
  property var entries: []
  property string warning: ""
  property string siftPath: ""
  property string historyPath: ""
  property bool active: false
  property bool _pending: false

  // First PATH, then the fixed locations. The fixed locations matter because
  // the shell's PATH can differ from an interactive terminal.
  readonly property string locateScript: [
    'if p=$(command -v sift 2>/dev/null) && [ -x "$p" ]; then',
    '  case "$p" in /*) printf "%s\\n" "$p"; exit 0;; esac',
    'fi',
    'for p in "$HOME/.local/bin/sift" "$HOME/go/bin/sift" /usr/bin/sift; do',
    '  if [ -x "$p" ]; then printf "%s\\n" "$p"; exit 0; fi',
    'done',
    'exit 1'
  ].join("\n")

  function refresh() {
    if (!root.active) return
    if (root.locateProc.running || root.historyProc.running || root.pathProc.running) {
      root._pending = true
      return
    }
    root._pending = false
    root.warning = ""
    root.locateProc.running = true
    root.locateTimer.restart()
  }

  function finishStep() {
    if (!root._pending) return
    root._pending = false
    root.refresh()
  }

  function markMissing() {
    root.siftPath = ""
    root.entries = []
    root.historyPath = ""
    root.warning = ""
    root.state = "missing"
    root.finishStep()
  }

  function readHistory() {
    if (root.siftPath === "") {
      root.markMissing()
      return
    }
    root.historyProc.command = [root.siftPath, "history", "--json", "--limit", "20"]
    root.historyProc.running = true
    root.historyTimer.restart()
  }

  function readHistoryPath() {
    if (root.siftPath === "") return
    root.pathProc.command = [root.siftPath, "history", "--path"]
    root.pathProc.running = true
    root.pathTimer.restart()
  }

  property Process locateProc: Process {
    command: ["/usr/bin/sh", "-c", root.locateScript]
    stdout: StdioCollector { id: locateOut; waitForEnd: true }
    stderr: StdioCollector { id: locateErr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      root.locateTimer.stop()
      var path = String(locateOut.text || "").trim().split("\n")[0]
      if (exitCode !== 0 || exitStatus !== 0 || path === "") {
        root.markMissing()
        return
      }
      root.siftPath = path
      root.readHistory()
    }
  }

  property Process historyProc: Process {
    stdout: StdioCollector { id: historyOut; waitForEnd: true }
    stderr: StdioCollector { id: historyErr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      root.historyTimer.stop()
      if (exitCode !== 0 || exitStatus !== 0) {
        var message = String(historyErr.text || "").trim()
        root.entries = []
        root.warning = message !== "" ? message : "sift history failed."
        root.state = "outdated"
        root.historyPath = ""
        root.finishStep()
        return
      }

      var parsed = Model.parseHistory(String(historyOut.text || ""))
      root.entries = Model.latestPerRoot(parsed.entries)
      root.warning = parsed.warning
      root.state = "ready"
      root.readHistoryPath()
    }
  }

  property Process pathProc: Process {
    stdout: StdioCollector { id: pathOut; waitForEnd: true }
    stderr: StdioCollector { id: pathErr; waitForEnd: true }

    onExited: function(exitCode, exitStatus) {
      root.pathTimer.stop()
      if (exitCode === 0 && exitStatus === 0) {
        var path = String(pathOut.text || "").trim().split("\n")[0]
        if (path !== "") root.historyPath = path
      } else {
        root.historyPath = ""
      }
      root.finishStep()
    }
  }

  property FileView historyFile: FileView {
    path: root.historyPath
    watchChanges: root.active && root.historyPath !== ""
    // Watch only. Never preload or reload the JSONL; entries come solely from
    // the public `sift history --json` contract.
    preload: false
    printErrors: false

    // Phase 0 verified that the watcher survives an atomic rename. It also
    // watches the parent directory, so a first-ever history file is noticed.
    onFileChanged: root.refreshTimer.restart()
  }

  property Timer refreshTimer: Timer {
    interval: 150
    repeat: false
    onTriggered: root.refresh()
  }

  property Timer locateTimer: Timer {
    interval: 1500
    repeat: false
    onTriggered: {
      root.locateProc.running = false
      root.markMissing()
    }
  }

  property Timer historyTimer: Timer {
    interval: 4000
    repeat: false
    onTriggered: {
      root.historyProc.running = false
      root.entries = []
      root.historyPath = ""
      root.warning = "sift history timed out."
      root.state = "outdated"
      root.finishStep()
    }
  }

  property Timer pathTimer: Timer {
    interval: 1500
    repeat: false
    onTriggered: {
      root.pathProc.running = false
      root.historyPath = ""
      root.finishStep()
    }
  }
}
