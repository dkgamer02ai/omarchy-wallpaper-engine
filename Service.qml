// `omarchy plugin add` clones and validates, but has no post-install hook, so
// the plugin does its own setup the first time the shell loads it: link the
// CLI, add the autostart + theme-set hook, and write the menu > Style row.
//
// install.sh is idempotent, so the guard is only there to keep every shell
// start from re-running it.
import QtQuick
import Quickshell.Io

Item {
  id: root

  // Injected by omarchy-shell (the plugin loader).
  property var shell: null

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")

  Process {
    running: true
    command: ["bash", "-c",
      'grep -q omarchy-we-menu-start "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc" 2>/dev/null'
      + ' || bash ' + JSON.stringify(root.pluginDir + "/install.sh") + ' --no-deps']
    stdout: StdioCollector {
      onStreamFinished: if (text.trim()) console.log("omarchy-we setup:", text.trim())
    }
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) console.warn("omarchy-we setup:", text.trim())
    }
  }
}
