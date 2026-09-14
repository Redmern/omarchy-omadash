import QtQuick
import Quickshell
import Quickshell.Io

// Installed .desktop entries, enumerated directly (panel-kind plugins don't
// get the host's app-library facade, so this reads the files itself).
Item {
  id: apps

  property var entries: []

  // Emitted after launch() fires off the app, so the panel can dismiss.
  signal launched()

  function refresh() {
    appsProcess.running = true
  }

  function applyList(text) {
    apps.entries = String(text).split("\n").map(function(line) {
      var cols = line.split("\t")
      if (cols.length < 2 || !cols[0]) return null
      var icon = cols[2] || ""
      var iconUrl
      if (icon.indexOf("/") === 0) iconUrl = "file://" + icon
      else if (icon.length > 0) iconUrl = Quickshell.iconPath(icon, true)
      else iconUrl = Quickshell.iconPath("application-x-executable", true)
      return { id: cols[0], name: cols[1], icon: iconUrl }
    }).filter(function(e) { return e !== null })
  }

  function launch(item) {
    appsLaunchProcess.command = ["uwsm-app", "--", "gtk-launch", item.id + ".desktop"]
    appsLaunchProcess.running = true
    apps.launched()
  }

  Process {
    id: appsProcess
    command: ["bash", "-c",
      "for f in /usr/share/applications/*.desktop " +
      "\"$HOME/.local/share/applications\"/*.desktop; do [ -f \"$f\" ] || continue; " +
      "awk -F'=' -v file=\"$f\" '" +
      "/^\\[Desktop Entry\\]/{sect=1; next} " +
      "/^\\[/{sect=0} " +
      "sect && /^Name=/ && name==\"\" {name=substr($0,6)} " +
      "sect && /^Icon=/ && icon==\"\" {icon=substr($0,6)} " +
      "sect && /^NoDisplay=true/{skip=1} " +
      "sect && /^Hidden=true/{skip=1} " +
      "END{ if(!skip && name!=\"\"){ n=split(file,a,\"/\"); id=a[n]; sub(/\\.desktop$/,\"\",id); " +
      "print id \"\\t\" name \"\\t\" icon } }' \"$f\"; " +
      "done | sort -t $'\\t' -k2,2 -f -u"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: apps.applyList(text)
    }
  }

  Process { id: appsLaunchProcess }
}
