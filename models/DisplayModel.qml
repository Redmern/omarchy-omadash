import QtQuick
import Quickshell.Io

// Brightness, text size, monitor scale, and night light. No periodic
// refresh — the panel calls refresh() when the Display screen opens and
// after any change that needs re-confirming from the system.
Item {
  id: disp

  // Emitted after applyState() updates monitorScale, so the panel can
  // resync its keyboard scale-selection cursor to match reality.
  signal stateApplied()

  property bool brightnessAvailable: true
  property real brightnessPct: 100
  property string focusedMonitor: ""
  property string monitorName: ""
  property real monitorScale: 1
  // Same fixed stops (and CLI) the built-in Display bar-widget uses, so
  // this stays in lockstep with the shell's own text size.
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]
  property int textScalePx: 12
  readonly property var scalePresets: [1, 1.25, 1.6, 2, 3, 4]
  // Derived, never set directly — that was the source of a bug where
  // adjusting intensity could desync the on/off state from the actual
  // temperature and appear to randomly toggle.
  readonly property bool nightlightOn: nightlightTemp < 6000
  property int nightlightTemp: 4000

  function nearestScaleIndex(scale) {
    var best = 0
    var bestDist = Infinity
    for (var i = 0; i < disp.scalePresets.length; i++) {
      var d = Math.abs(disp.scalePresets[i] - scale)
      if (d < bestDist) { bestDist = d; best = i }
    }
    return best
  }

  function refresh() {
    dispProcess.running = true
    dispTextSizeProcess.running = true
    dispNightlightProcess.running = true
    // Ensure the daemon exists once per screen-open, not on every intensity
    // step — checking/spawning it on each step raced with hyprsunset still
    // booting and could restart it mid-adjustment, briefly dropping its
    // socket and reading back as "off".
    dispEnsureHyprsunsetProcess.running = true
  }

  function applyState(text) {
    var lines = String(text || "").split("\n")
    var brightness = String(lines[0] || "").trim()
    disp.brightnessAvailable = brightness !== "unavailable" && brightness !== ""
    disp.brightnessPct = disp.brightnessAvailable ? Math.max(0, Math.min(100, parseInt(brightness, 10))) : 0
    disp.focusedMonitor = String(lines[5] || "").trim()
    disp.monitorName = disp.focusedMonitor
    disp.monitorScale = parseFloat(lines[6] || "1") || 1
    disp.stateApplied()
  }

  function applyTextSize(text) {
    var m = String(text || "").match(/text size:\s*(\d+)/)
    if (m) disp.textScalePx = parseInt(m[1])
  }

  function nearestTextStopIndex(px) {
    var best = 0
    var bestDist = Infinity
    for (var i = 0; i < disp.textSizeStops.length; i++) {
      var d = Math.abs(disp.textSizeStops[i] - px)
      if (d < bestDist) { bestDist = d; best = i }
    }
    return best
  }

  function setBrightness(pct) {
    pct = Math.max(1, Math.min(100, Math.round(pct)))
    disp.brightnessPct = pct
    dispSetProcess.command = ["omarchy-brightness-display", "--no-osd", "--monitor", disp.focusedMonitor, pct + "%"]
    dispSetProcess.running = true
  }

  function setTextSizePx(px) {
    var idx = disp.nearestTextStopIndex(px)
    var snapped = disp.textSizeStops[Math.max(0, Math.min(disp.textSizeStops.length - 1, idx))]
    disp.textScalePx = snapped
    dispTextScaleProcess.command = ["omarchy-display-text-size", String(snapped)]
    dispTextScaleProcess.running = true
  }

  function setMonitorScale(scale) {
    if (!disp.monitorName) return
    disp.monitorScale = scale
    var monitor = disp.monitorName
    // omarchy-hyprland-monitor-scaling applies the change live, but its own
    // monitors.lua persistence only rewrites a bare catch-all ("") entry —
    // when a monitor also has its own dedicated line (as after `hyprctl
    // monitors` "refine" step), that line is left stale and the monitor
    // watcher reasserts the old scale on the next monitor event. Patch the
    // monitor's own line too, only if the file already has it in the
    // expected generated shape.
    dispScaleProcess.command = ["bash", "-c",
      "omarchy-hyprland-monitor-scaling " + scale + "; " +
      "f=\"$HOME/.config/hypr/monitors.lua\"; " +
      "grep -qE 'output = \"" + monitor + "\"' \"$f\" 2>/dev/null && " +
      "sed -i -E 's/(output = \"" + monitor + "\"[^}]*scale = )[0-9.]+/\\1" + scale + "/' \"$f\""
    ]
    dispScaleProcess.running = true
  }

  function applyNightlight(text) {
    try {
      var status = JSON.parse(text)
      if (status.temperature) disp.nightlightTemp = status.temperature
      else if (!status.enabled) disp.nightlightTemp = 6500
    } catch (e) { }
  }

  function toggleNightlight() {
    disp.setNightlightTemp(disp.nightlightOn ? 6500 : 4000)
  }

  function setNightlightTemp(temp) {
    temp = Math.round(Math.max(2500, Math.min(6500, temp)))
    disp.nightlightTemp = temp
    // Just the temperature call, no spawn/pgrep dance here — that only runs
    // once in refresh(). A couple of quick retries covers the daemon still
    // finishing its own boot right after that ensure-spawn.
    dispNightlightTempProcess.command = ["bash", "-c",
      "for _ in 1 2 3; do hyprctl hyprsunset temperature " + temp + " >/dev/null 2>&1 && break; sleep 0.1; done"
    ]
    dispNightlightTempProcess.running = true
  }

  Process {
    id: dispProcess
    command: ["omarchy-monitor-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: disp.applyState(text)
    }
  }

  Process {
    id: dispNightlightProcess
    command: ["omarchy-toggle-nightlight", "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: disp.applyNightlight(text)
    }
  }

  Process { id: dispNightlightTempProcess }

  Process {
    id: dispEnsureHyprsunsetProcess
    command: ["bash", "-c", "pgrep -x hyprsunset >/dev/null || setsid uwsm-app -- hyprsunset >/dev/null 2>&1 &"]
  }

  Process {
    id: dispTextSizeProcess
    command: ["omarchy-display-text-size"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: disp.applyTextSize(text)
    }
  }

  Process { id: dispSetProcess }
  Process { id: dispTextScaleProcess }
  Process { id: dispScaleProcess; onExited: disp.refresh() }
}
