import QtQuick
import Quickshell.Io

// Wi-Fi state + data fetching. `active` should be bound to whether the
// network screen is currently visible, to drive the periodic refresh.
Item {
  id: net

  property bool active: false

  property string iface: ""
  property string ssid: ""
  property string ip: ""
  property string gateway: ""
  property string dns: "DHCP"
  property real freqMHz: 0
  property string pingMs: ""
  property int lossPct: 0
  property real rxBytes: 0
  property real txBytes: 0
  property real rxRateKBs: 0
  property real txRateKBs: 0
  property real lastRx: -1
  property real lastTx: -1
  property var knownNetworks: []
  property var otherNetworks: []

  property bool radioOn: true

  function bandLabel() {
    return freqMHz >= 5000 ? "5GHz" : (freqMHz > 0 ? "2.4GHz" : "—")
  }

  function formatBytes(bytes) {
    if (!bytes || bytes <= 0) return "0 MB"
    var mb = bytes / (1024 * 1024)
    if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB"
    return mb.toFixed(1) + " MB"
  }

  function refresh() {
    netProcess.running = true
  }

  function applyStats(text) {
    var parts = String(text).split("###KNOWN###")
    var statsText = parts[0] || ""
    var rest = (parts[1] || "").split("###OTHER###")
    var knownText = rest[0] || ""
    var otherText = rest[1] || ""

    var fields = {}
    statsText.split("\n").forEach(function(line) {
      var tab = line.indexOf("\t")
      if (tab < 0) return
      fields[line.slice(0, tab)] = line.slice(tab + 1)
    })

    net.iface = fields.iface || ""
    net.ip = fields.ip || ""
    net.gateway = fields.gateway || ""
    net.ssid = fields.ssid || net.iface
    net.freqMHz = parseFloat(fields.freq || "0") || 0
    net.pingMs = fields.router_ping_ms || fields.internet_ping_ms || ""
    net.lossPct = net.pingMs ? 0 : 100

    var rx = parseFloat(fields.rx_bytes || "0") || 0
    var tx = parseFloat(fields.tx_bytes || "0") || 0
    if (net.lastRx >= 0) {
      net.rxRateKBs = Math.max(0, (rx - net.lastRx) / 1024 / 2)
      net.txRateKBs = Math.max(0, (tx - net.lastTx) / 1024 / 2)
    }
    net.lastRx = rx
    net.lastTx = tx
    net.rxBytes = rx
    net.txBytes = tx

    var dnsProvider = fields.dns || "DHCP"
    net.dns = dnsProvider

    var known = knownText.split("\n").map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
    var others = otherText.split("\n").map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 && s.indexOf(":") >= 0 })

    net.knownNetworks = known
    net.otherNetworks = others.map(function(line) {
      var idx = line.split(":")
      return { inUse: idx[0] === "*", ssid: idx[1] || "", secured: (idx[2] || "") !== "" }
    }).filter(function(n) { return n.ssid.length > 0 && n.ssid !== net.ssid })
  }

  function setDns(provider) {
    if (provider === "Custom") {
      dnsCustomProcess.running = true
    } else {
      dnsProcess.command = ["omarchy-dns", provider]
      dnsProcess.running = true
    }
  }

  function toggleRadio() {
    radioOn = !radioOn
    radioProcess.command = ["nmcli", "radio", "wifi", radioOn ? "on" : "off"]
    radioProcess.running = true
  }

  function connectTo(ssid) {
    connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid]
    connectProcess.running = true
  }

  Timer {
    interval: 2000
    repeat: true
    running: net.active
    onTriggered: net.refresh()
  }

  Process {
    id: netProcess
    command: ["bash", "-c",
      "omarchy-network-status --verbose; echo '###KNOWN###'; " +
      "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1}'; " +
      "echo '###OTHER###'; nmcli -t -f IN-USE,SSID,SECURITY dev wifi list 2>/dev/null | awk -F: '!seen[$2]++ && $2!=\"\"'; " +
      "echo \"dns\t$(omarchy-dns 2>/dev/null)\""
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: net.applyStats(text)
    }
  }

  Process { id: dnsProcess }
  Process { id: dnsCustomProcess; command: ["omarchy-launch-floating-terminal-with-presentation", "omarchy-dns Custom"] }
  Process { id: radioProcess }
  Process { id: connectProcess }
}
