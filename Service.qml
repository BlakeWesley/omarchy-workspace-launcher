import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Startup workspace layout.
//
// apply-layout does the real work. It is started in its own session so a
// plugin reload during shell startup cannot kill it halfway through the run.
// Its JSON result goes to a file, which is what `status` reads.
Item {
  id: root

  // Injected by omarchy-shell's service loader.
  property var shell: null
  property var manifest: null

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/blake.workspace-launcher"
  readonly property string scriptPath: pluginDir + "/scripts/apply-layout"
  readonly property string resultPath: Quickshell.env("HOME") + "/.local/state/omarchy/workspace-launcher.result"

  property bool started: false

  function applyLayout(force) {
    var args = ["setsid", "--fork", "bash", scriptPath]
    if (force) args.push("--force")

    launcher.command = args
    launcher.running = true
    return "started"
  }

  Component.onCompleted: {
    if (started) return
    started = true
    Qt.callLater(function() { root.applyLayout(false) })
  }

  Process {
    id: launcher
    command: ["setsid", "--fork", "bash", root.scriptPath]

    onExited: function(exitCode) {
      if (exitCode !== 0)
        console.warn("workspace-launcher: could not start apply-layout (exit " + exitCode + ")")
    }
  }

  FileView {
    id: resultFile
    path: root.resultPath
    blockLoading: true
    watchChanges: true
    printErrors: false
  }

  // A run can create the result file after the service has loaded, which the
  // watcher does not always pick up. Poll it so `status` is never stale.
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: resultFile.reload()
  }

  ShellIpc {
    target: "blake.workspace-launcher"

    // Re-apply the layout without launching a second copy of anything that is
    // already running. The script's lock makes a concurrent call a no-op.
    function apply() {
      return root.applyLayout(true)
    }

    function status() {
      var text = String(resultFile.text() || "").trim()
      return text || '{"status":"idle"}'
    }
  }
}
