import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Startup workspace layout.
//
// The actual work lives in scripts/apply-layout: it waits for Hyprland, adds
// temporary window rules, launches the apps and settles them onto their
// workspaces. Keeping it in bash means a shell reload cannot leave a
// half-moved window behind, and the same script can be run by hand.
Item {
  id: root

  // Injected by omarchy-shell's service loader.
  property var shell: null
  property var manifest: null

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/blake.workspace-launcher"
  readonly property string scriptPath: pluginDir + "/scripts/apply-layout"

  property bool running: false
  property bool started: false
  property string lastResult: ""
  property int lastExitCode: -1

  function applyLayout(force) {
    if (running) return "already running"

    var args = ["bash", scriptPath]
    if (force) args.push("--force")

    runner.command = args
    running = true
    runner.running = true
    return "started"
  }

  Component.onCompleted: {
    if (started) return
    started = true
    // Let the shell finish mounting before spawning processes; the script
    // waits for Hyprland itself.
    Qt.callLater(function() { root.applyLayout(false) })
  }

  Process {
    id: runner
    command: ["bash", root.scriptPath]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lastResult = String(text || "").trim()
    }

    onExited: function(exitCode) {
      root.running = false
      root.lastExitCode = exitCode
      if (exitCode !== 0)
        console.warn("workspace-launcher: exit " + exitCode + " " + root.lastResult)
      else
        console.info("workspace-launcher: " + root.lastResult)
    }
  }

  ShellIpc {
    target: "blake.workspace-launcher"

    // Re-apply the layout without launching a second copy of anything that is
    // already running. Handy after changing layout.json or moving windows.
    function apply() {
      return root.applyLayout(true)
    }

    function status() {
      return root.lastResult || '{"status":"idle"}'
    }
  }
}
