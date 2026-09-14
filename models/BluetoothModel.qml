import QtQuick
import Quickshell.Io

// Bluetooth device list + the open device-detail sub-view's state.
// `active` drives the device-list refresh timer, `detailActive` drives the
// detail-view (battery/trust) refresh timer.
Item {
  id: bt

  property bool active: false
  property bool detailActive: false

  property bool powered: true
  property bool scanning: false
  property var devices: []

  function refresh() { btProcess.running = true }

  function startScan() {
    bt.scanning = true
    btScanProcess.running = true
  }

  function applyStats(text) {
    var parts = String(text).split("###DEVICES###")
    var powerLine = (parts[0] || "").trim()
    var rest = (parts[1] || "").split("###PAIRED###")
    var deviceLines = (rest[0] || "").split("\n")
    var rest2 = (rest[1] || "").split("###CONNECTED###")
    var pairedLines = (rest2[0] || "").split("\n")
    var connectedLines = (rest2[1] || "").split("\n")

    bt.powered = powerLine.toLowerCase() === "yes"

    var connectedMacs = {}
    connectedLines.forEach(function(line) {
      var m = line.match(/Device\s+(\S+)/)
      if (m) connectedMacs[m[1]] = true
    })
    var pairedMacs = {}
    pairedLines.forEach(function(line) {
      var m = line.match(/Device\s+(\S+)/)
      if (m) pairedMacs[m[1]] = true
    })

    var list = deviceLines.map(function(line) {
      var m = line.match(/Device\s+(\S+)\s+(.*)/)
      if (!m) return null
      return {
        mac: m[1],
        name: m[2],
        connected: !!connectedMacs[m[1]],
        paired: !!pairedMacs[m[1]]
      }
    }).filter(function(d) { return d !== null })

    list.sort(function(a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.paired !== b.paired) return a.paired ? -1 : 1
      return a.name.localeCompare(b.name)
    })
    bt.devices = list

    // Keep an open detail view in sync with the device it's showing.
    if (bt.detail.mac) {
      var updated = list.find(function(d) { return d.mac === bt.detail.mac })
      if (updated) bt.detail = Object.assign({}, bt.detail, updated)
    }
  }

  function togglePower() {
    bt.powered = !bt.powered
    btPowerProcess.command = ["bluetoothctl", "power", bt.powered ? "on" : "off"]
    btPowerProcess.running = true
  }

  function toggleConnect(device) {
    if (device.connected) {
      btConnectProcess.command = ["bluetoothctl", "disconnect", device.mac]
    } else if (device.paired) {
      btConnectProcess.command = ["bluetoothctl", "connect", device.mac]
    } else {
      btConnectProcess.command = ["bash", "-c",
        "bluetoothctl pair " + device.mac + " && bluetoothctl connect " + device.mac]
    }
    btConnectProcess.running = true
  }

  // --- Device detail (battery, trust, forget) ---
  property var detail: ({})
  signal detailForgotten()

  function showDetail(device) {
    bt.detail = device
    bt.refreshDetail()
  }

  function refreshDetail() {
    if (!bt.detail.mac) return
    btInfoProcess.command = ["bluetoothctl", "info", bt.detail.mac]
    btInfoProcess.running = true
  }

  function applyDetailInfo(text) {
    var lines = String(text).split("\n")
    var info = {}
    lines.forEach(function(line) {
      var m = line.match(/^\s*([A-Za-z ]+):\s*(.*)$/)
      if (!m) return
      info[m[1].trim()] = m[2].trim()
    })

    var batteryMatch = (info["Battery Percentage"] || "").match(/\((\d+)\)/)
    bt.detail = Object.assign({}, bt.detail, {
      icon: info["Icon"] || "",
      trusted: info["Trusted"] === "yes",
      battery: batteryMatch ? parseInt(batteryMatch[1]) : -1
    })
  }

  function forget(device) {
    btForgetProcess.command = ["bluetoothctl", "remove", device.mac]
    btForgetProcess.running = true
  }

  Process {
    id: btInfoProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: bt.applyDetailInfo(text)
    }
  }

  Timer {
    interval: 4000
    repeat: true
    running: bt.detailActive
    onTriggered: bt.refreshDetail()
  }

  Process { id: btForgetProcess; onExited: { bt.refresh(); bt.detailForgotten() } }

  Timer {
    interval: 3000
    repeat: true
    running: bt.active
    onTriggered: bt.refresh()
  }

  Process {
    id: btProcess
    command: ["bash", "-c",
      "bluetoothctl show | awk -F': ' '/Powered/{print $2}'; echo '###DEVICES###'; " +
      "bluetoothctl devices; echo '###PAIRED###'; bluetoothctl devices Paired; " +
      "echo '###CONNECTED###'; bluetoothctl devices Connected"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: bt.applyStats(text)
    }
  }

  Process {
    id: btScanProcess
    command: ["bluetoothctl", "--timeout", "5", "scan", "on"]
    onExited: { bt.scanning = false; bt.refresh() }
  }

  Process { id: btPowerProcess }
  Process { id: btConnectProcess; onExited: bt.refresh() }
}
