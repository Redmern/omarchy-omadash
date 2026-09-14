import QtQuick
import Quickshell.Io

// Output/input volume, mute, and device lists. `active` drives the
// periodic refresh timer.
Item {
  id: audio

  property bool active: false

  property bool muted: false
  property real volumePct: 0
  property var sinks: []
  property string defaultSink: ""

  property bool inputMuted: false
  property real inputVolumePct: 0
  property var sources: []
  property string defaultSource: ""

  function refresh() { audioProcess.running = true }

  function applyStats(text) {
    var sections = String(text).split("###SOURCES###")
    var headText = sections[0] || ""
    var sourcesText = sections[1] || ""

    var lines = headText.split("\n")
    var muteLine = lines[0] || ""
    var volLine = lines[1] || ""
    var defaultLine = (lines[2] || "").trim()
    var inMuteLine = lines[3] || ""
    var inVolLine = lines[4] || ""
    var defaultInLine = (lines[5] || "").trim()

    audio.muted = /yes/i.test(muteLine)
    var m = volLine.match(/(\d+)%/)
    audio.volumePct = m ? parseInt(m[1]) : 0
    audio.defaultSink = defaultLine

    audio.inputMuted = /yes/i.test(inMuteLine)
    var mi = inVolLine.match(/(\d+)%/)
    audio.inputVolumePct = mi ? parseInt(mi[1]) : 0
    audio.defaultSource = defaultInLine

    var sinkIdx = headText.indexOf("###SINKS###")
    var sinkLines = sinkIdx >= 0 ? headText.slice(sinkIdx + "###SINKS###".length).split("\n") : []
    audio.sinks = sinkLines.map(function(line) {
      var cols = line.split("\t")
      if (cols.length < 2) return null
      return { name: cols[0], label: cols[1], active: cols[0] === audio.defaultSink }
    }).filter(function(s) { return s !== null })

    audio.sources = sourcesText.split("\n").map(function(line) {
      var cols = line.split("\t")
      if (cols.length < 2) return null
      return { name: cols[0], label: cols[1], active: cols[0] === audio.defaultSource }
    }).filter(function(s) { return s !== null })
  }

  function toggleMute() {
    audioMuteProcess.running = true
  }

  function toggleInputMute() {
    audioInputMuteProcess.running = true
  }

  function setVolume(pct) {
    pct = Math.max(0, Math.min(100, Math.round(pct)))
    audio.volumePct = pct
    audioVolumeProcess.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", pct + "%"]
    audioVolumeProcess.running = true
  }

  function setInputVolume(pct) {
    pct = Math.max(0, Math.min(100, Math.round(pct)))
    audio.inputVolumePct = pct
    audioInputVolumeProcess.command = ["pactl", "set-source-volume", "@DEFAULT_SOURCE@", pct + "%"]
    audioInputVolumeProcess.running = true
  }

  function setDefaultSink(name) {
    audioSinkProcess.command = ["pactl", "set-default-sink", name]
    audioSinkProcess.running = true
  }

  function setDefaultSource(name) {
    audioSourceProcess.command = ["pactl", "set-default-source", name]
    audioSourceProcess.running = true
  }

  Timer {
    interval: 3000
    repeat: true
    running: audio.active
    onTriggered: audio.refresh()
  }

  Process {
    id: audioProcess
    command: ["bash", "-c",
      "pactl get-sink-mute @DEFAULT_SINK@; pactl get-sink-volume @DEFAULT_SINK@ | head -1; " +
      "pactl get-default-sink; pactl get-source-mute @DEFAULT_SOURCE@; " +
      "pactl get-source-volume @DEFAULT_SOURCE@ | head -1; pactl get-default-source; " +
      "echo '###SINKS###'; pactl -f json list sinks | " +
      "jq -r '.[] | \"\\(.name)\\t\\(.description // .name)\"'; " +
      "echo '###SOURCES###'; pactl -f json list sources | " +
      "jq -r '.[] | select(.name | endswith(\".monitor\") | not) | \"\\(.name)\\t\\(.description // .name)\"'"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: audio.applyStats(text)
    }
  }

  Process { id: audioMuteProcess; command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]; onExited: audio.refresh() }
  Process { id: audioInputMuteProcess; command: ["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]; onExited: audio.refresh() }
  Process { id: audioVolumeProcess }
  Process { id: audioInputVolumeProcess }
  Process { id: audioSinkProcess; onExited: audio.refresh() }
  Process { id: audioSourceProcess; onExited: audio.refresh() }
}
