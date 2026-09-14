import QtQuick
import Quickshell.Io

// Battery detail (via upower) and power-profile list. `active` drives the
// periodic refresh timer.
Item {
  id: power

  property bool active: false

  property bool present: false
  property int percent: 0
  property string state: ""
  property real energyFullWh: 0
  property int chargeCycles: 0
  property string timeLabel: "-"
  property var profiles: []
  property string activeProfile: ""

  function statusLabel() {
    switch (power.state) {
      case "fully-charged": return "FULLY CHARGED"
      case "charging": return "CHARGING"
      case "discharging": return "DISCHARGING"
      case "pending-charge": return "PENDING CHARGE"
      case "pending-discharge": return "PENDING DISCHARGE"
      default: return power.state.toUpperCase()
    }
  }

  function refresh() { powerProcess.running = true }

  function applyStats(text) {
    var sections = String(text).split("###PROFILES###")
    var upowerText = sections[0] || ""
    var profilesText = sections[1] || ""

    var m
    m = upowerText.match(/percentage:\s*(\d+)%/)
    power.percent = m ? parseInt(m[1]) : 0
    m = upowerText.match(/state:\s*(\S+)/)
    power.state = m ? m[1] : ""
    power.present = power.state.length > 0
    m = upowerText.match(/energy-full:\s*([\d.]+)\s*Wh/)
    power.energyFullWh = m ? parseFloat(m[1]) : 0
    m = upowerText.match(/charge-cycles:\s*(\d+)/)
    power.chargeCycles = m ? parseInt(m[1]) : 0
    m = upowerText.match(/time to (?:full|empty):\s*(.+)/)
    power.timeLabel = m ? m[1].trim() : "-"

    power.profiles = profilesText.split("\n").map(function(line) {
      var cols = line.split("\t")
      if (!cols[0]) return null
      return { name: cols[0].trim(), active: cols[1] === "1" }
    }).filter(function(p) { return p !== null })

    var activeEntry = power.profiles.find(function(p) { return p.active })
    power.activeProfile = activeEntry ? activeEntry.name : ""
  }

  function setProfile(name) {
    power.activeProfile = name
    powerProfileProcess.command = ["powerprofilesctl", "set", name]
    powerProfileProcess.running = true
  }

  Timer {
    interval: 5000
    repeat: true
    running: power.active
    onTriggered: power.refresh()
  }

  Process {
    id: powerProcess
    command: ["bash", "-c",
      "upower -i \"$(upower -e | grep battery)\" 2>/dev/null; " +
      "echo '###PROFILES###'; omarchy-powerprofiles-list --active-state"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: power.applyStats(text)
    }
  }

  Process { id: powerProfileProcess; onExited: power.refresh() }
}
