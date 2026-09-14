import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./models"
import "./views"

// Minimal Omarchy "panel" plugin: a centered popup window toggled by a
// Hyprland keybind (see README.md for the exact bind).
//
// Host contract (same one every built-in panel plugin follows, e.g.
// /usr/share/omarchy/shell/plugins/panels/wifiqr/Panel.qml):
//   - `shell` and `manifest` are injected by omarchy-shell after this
//     component is instantiated.
//   - open(payloadJson) is called when the plugin is summoned/toggled open.
//   - close() is called when the host hides it (e.g. `shell hide`).
//   - Esc / click-outside should call dismiss(), which tells the host to
//     hide us via shell.hide(id) so its open-panel bookkeeping stays in
//     sync, rather than just flipping local visibility.
//
// This file is the shell: window, keybinds, and screen-switching state.
// Each tile's live system state lives in its own *Model.qml, and each
// screen's UI lives in its own *View.qml, both alongside this file.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  // Window stays alive for the closing animation, then hides for real.
  property bool windowVisible: false

  // "grid" (tile launcher) or one of the detail-view names below. The card
  // morphs size/content between them.
  property string screen: "grid"

  // Each tile toggles a real Omarchy panel/menu route via the shell's own
  // IPC (same commands `omarchy-menu`/keybinds use), so it does what it says.
  // Wi-Fi instead switches to an embedded detail view (`view` below).
  readonly property var tiles: [
    { label: "Wi-Fi", icon: "", view: "network" },
    { label: "Bluetooth", icon: "", view: "bluetooth" },
    { label: "Audio", icon: "", view: "audio" },
    { label: "Display", icon: "", view: "display" },
    { label: "Battery", icon: "", view: "battery" },
    { label: "Power", icon: "", view: "poweractions" },
    { label: "Apps", icon: "", view: "apps" },
    { label: "Quick", icon: "", view: "quick" },
    { label: "Calendar", icon: "", view: "calendar" }
  ]
  readonly property int gridColumns: 3

  // System power actions shown as tiles on their own screen. Each needs a
  // held key press (see power-hold state below) rather than a plain tap,
  // since these are destructive; h/l/j/k are free on that screen since it's
  // letter-driven only, no arrow nav.
  readonly property var powerActions: [
    { label: "Lock", icon: "", command: ["omarchy-system-lock"] },
    { label: "Suspend", icon: "", command: ["systemctl", "suspend"] },
    { label: "Logout", icon: "", command: ["omarchy-system-logout"] },
    { label: "Reboot", icon: "", command: ["omarchy-system-reboot"] },
    { label: "Shutdown", icon: "", command: ["omarchy-system-shutdown"] }
  ]
  property var powerKeys: root.computeLetterKeys(root.powerActions, [root.keybinds.activate])

  // Small non-destructive command tiles on their own screen, run immediately
  // (no hold) and dismiss, same as a plain grid tile with a command.
  readonly property var quickActions: [
    { label: "Screenshot", icon: "", command: ["omarchy-capture-screenshot"] },
    { label: "Record", icon: "", command: ["bash", "-c",
      "pgrep -f '^gpu-screen-recorder' >/dev/null && omarchy-capture-screenrecording --stop-recording || omarchy-capture-screenrecording"] },
    { label: "Emoji", icon: "", command: ["omarchy-menu-emoji"] },
    { label: "Clipboard", icon: "", command: ["omarchy-shell", "shell", "toggle", "omarchy.clipboard"] },
    { label: "Stay Awake", icon: "", command: ["omarchy-toggle-idle", "toggle"] },
    { label: "Do Not Disturb", icon: "", command: ["omarchy-toggle-notification-silencing"] },
    { label: "Reminders", icon: "", command: ["omarchy-reminder", "show"] }
  ]
  property var quickKeys: root.computeLetterKeys(root.quickActions,
    [root.keybinds.up, root.keybinds.down, root.keybinds.left, root.keybinds.right, root.keybinds.activate])

  // Shared "first free letter of the label, else any free a-z" assignment
  // used for the main grid, the power-action tiles, and the quick tiles.
  function computeLetterKeys(items, reserved) {
    var used = {}
    reserved.forEach(function(k) { if (k) used[k] = true })

    var result = {}
    items.forEach(function(item) {
      var letters = item.label.toLowerCase().replace(/[^a-z]/g, "")
      var chosen = ""
      for (var i = 0; i < letters.length; i++) {
        if (!used[letters[i]]) { chosen = letters[i]; break }
      }
      if (!chosen) {
        for (var code = 97; code <= 122; code++) {
          var ch = String.fromCharCode(code)
          if (!used[ch]) { chosen = ch; break }
        }
      }
      used[chosen] = true
      result[item.label] = chosen
    })
    return result
  }

  // Rebindable single-key actions (letter keys only). Esc is always "back"
  // and is not rebindable. Persisted to keybinds.json next to this plugin.
  readonly property var defaultKeybinds: ({ up: "k", down: "j", left: "h", right: "l", activate: " ", search: "?" })
  property var keybinds: ({ up: "k", down: "j", left: "h", right: "l", activate: " ", search: "?" })
  // One quick-open letter per grid tile, keyed by tile.view. Defaults to the
  // tile label's first letter that doesn't clash with another binding,
  // falling through the label's later letters and finally any free a-z.
  property var tileKeys: ({})
  property string rebindingAction: ""

  function computeDefaultTileKeys() {
    var byView = root.computeLetterKeys(root.tiles,
      [root.keybinds.up, root.keybinds.down, root.keybinds.left, root.keybinds.right, root.keybinds.activate, "s"])
    var result = {}
    root.tiles.forEach(function(tile) { result[tile.view] = byView[tile.label] })
    return result
  }

  // --- Power action hold-to-confirm ---------------------------------------
  // Holding an action's key for powerHoldMs executes it immediately, with
  // powerHoldProgress (0..1) driving a fill animation on its tile. Releasing
  // early instead raises a yes/no confirmation for that action.
  readonly property int powerHoldMs: 900
  property string powerHoldLabel: ""
  property real powerHoldProgress: 0
  property var powerConfirmAction: null

  function startPowerHold(label) {
    if (root.powerHoldLabel === label) return
    root.powerHoldLabel = label
    root.powerHoldProgress = 0
    powerHoldTimer.elapsed = 0
    powerHoldTimer.running = true
  }

  function releasePowerHold() {
    if (!root.powerHoldLabel) return
    var label = root.powerHoldLabel
    var completed = root.powerHoldProgress >= 1
    powerHoldTimer.running = false
    root.powerHoldLabel = ""
    root.powerHoldProgress = 0
    if (!completed) {
      var action = root.powerActions.find(function(a) { return a.label === label })
      if (action) root.powerConfirmAction = action
    }
  }

  function cancelPowerHold() {
    powerHoldTimer.running = false
    root.powerHoldLabel = ""
    root.powerHoldProgress = 0
  }

  function runPowerAction(action) {
    powerActionProcess.command = action.command
    powerActionProcess.running = true
    root.dismissImmediate()
  }

  function confirmPowerAction(yes) {
    if (yes && root.powerConfirmAction) root.runPowerAction(root.powerConfirmAction)
    root.powerConfirmAction = null
  }

  Timer {
    id: powerHoldTimer
    interval: 30
    repeat: true
    property real elapsed: 0
    onTriggered: {
      elapsed += interval
      root.powerHoldProgress = Math.min(1, elapsed / root.powerHoldMs)
      if (elapsed >= root.powerHoldMs) {
        running = false
        var label = root.powerHoldLabel
        root.powerHoldLabel = ""
        root.powerHoldProgress = 0
        var action = root.powerActions.find(function(a) { return a.label === label })
        if (action) root.runPowerAction(action)
      }
    }
  }

  Process { id: powerActionProcess }

  // Quick-action tile selection (2-column grid, wraps like the main grid).
  readonly property int quickColumns: 3
  property int quickSelectedIndex: 0

  function moveQuickSelection(dx, dy) {
    var columns = root.quickColumns
    var count = root.quickActions.length
    var rows = Math.ceil(count / columns)
    var col = root.quickSelectedIndex % columns
    var row = Math.floor(root.quickSelectedIndex / columns)

    if (dx !== 0) {
      var rowStart = row * columns
      var rowLength = Math.min(columns, count - rowStart)
      col = (col + dx + rowLength) % rowLength
    }
    if (dy !== 0) {
      var lastRowLength = count - (rows - 1) * columns
      var colHeight = col < lastRowLength ? rows : rows - 1
      row = (row + dy + colHeight) % colHeight
      var newRowLength = Math.min(columns, count - row * columns)
      col = Math.min(col, newRowLength - 1)
    }

    var next = row * columns + col
    if (next >= 0 && next < count) root.quickSelectedIndex = next
  }

  function activateQuickSelection() {
    var action = root.quickActions[root.quickSelectedIndex]
    if (!action) return
    quickActionProcess.command = action.command
    quickActionProcess.running = true
    root.dismissImmediate()
  }

  Process { id: quickActionProcess }

  // --- Calendar --------------------------------------------------------
  // calendarSelected drives both the highlighted day and, via its
  // month/year, which month is displayed — so day-by-day hjkl navigation
  // (h/l = day, j/k = week) rolls into the next/previous month naturally.
  property var calendarSelected: new Date()
  readonly property int calendarMonth: calendarSelected.getMonth()
  readonly property int calendarYear: calendarSelected.getFullYear()

  function moveCalendarDay(delta) {
    var d = new Date(root.calendarSelected)
    d.setDate(d.getDate() + delta)
    root.calendarSelected = d
  }

  function moveCalendarMonth(delta) {
    var d = new Date(root.calendarSelected)
    d.setMonth(d.getMonth() + delta)
    root.calendarSelected = d
  }

  function resetCalendarToToday() {
    root.calendarSelected = new Date()
  }

  // Weeks as rows of {day, inMonth, isToday, isSelected}, Sunday-first, ISO
  // week number in a leading column (matches the reference calendar widget).
  function calendarWeeks() {
    var first = new Date(root.calendarYear, root.calendarMonth, 1)
    var startOffset = first.getDay()
    var gridStart = new Date(root.calendarYear, root.calendarMonth, 1 - startOffset)
    var today = new Date()
    var selected = root.calendarSelected

    function isoWeekNumber(date) {
      var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
      var dayNum = d.getUTCDay() || 7
      d.setUTCDate(d.getUTCDate() + 4 - dayNum)
      var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
      return Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
    }

    var weeks = []
    for (var w = 0; w < 6; w++) {
      var days = []
      var weekNum = 0
      for (var i = 0; i < 7; i++) {
        var d = new Date(gridStart)
        d.setDate(gridStart.getDate() + w * 7 + i)
        if (i === 0) weekNum = isoWeekNumber(d)
        days.push({
          day: d.getDate(),
          inMonth: d.getMonth() === root.calendarMonth,
          isToday: d.toDateString() === today.toDateString(),
          isSelected: d.toDateString() === selected.toDateString()
        })
      }
      weeks.push({ weekNum: weekNum, days: days })
    }
    return weeks
  }

  function calendarYearProgress() {
    var now = new Date()
    var start = new Date(now.getFullYear(), 0, 1)
    var end = new Date(now.getFullYear() + 1, 0, 1)
    return (now - start) / (end - start)
  }

  readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"]

  function keybindsPath() {
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/omadash/keybinds.json"
  }

  function loadKeybinds() {
    keybindsLoadProcess.running = true
  }

  function applyLoadedKeybinds(text) {
    var defaultTileKeys = root.computeDefaultTileKeys()
    var trimmed = String(text || "").trim()
    if (trimmed.length === 0) {
      root.tileKeys = defaultTileKeys
      return
    }
    try {
      var parsed = JSON.parse(trimmed)
      root.keybinds = Object.assign({}, root.defaultKeybinds, parsed.keybinds || {})
      root.tileKeys = Object.assign({}, root.computeDefaultTileKeys(), parsed.tileKeys || {})
    } catch (e) {
      root.tileKeys = defaultTileKeys
    }
  }

  function saveKeybinds() {
    var json = JSON.stringify({ keybinds: root.keybinds, tileKeys: root.tileKeys })
    var path = root.keybindsPath()
    keybindsSaveProcess.command = ["bash", "-c",
      "mkdir -p \"$(dirname " + JSON.stringify(path) + ")\" && cat > " +
      JSON.stringify(path) + " <<'EOF'\n" + json + "\nEOF"
    ]
    keybindsSaveProcess.running = true
  }

  function startRebind(action) {
    root.rebindingAction = action
  }

  function applyRebind(key) {
    if (!root.rebindingAction) return
    if (root.rebindingAction.indexOf("tile:") === 0) {
      var view = root.rebindingAction.slice(5)
      var updatedTiles = Object.assign({}, root.tileKeys)
      updatedTiles[view] = key
      root.tileKeys = updatedTiles
    } else {
      var updated = Object.assign({}, root.keybinds)
      updated[root.rebindingAction] = key
      root.keybinds = updated
    }
    root.rebindingAction = ""
    root.saveKeybinds()
  }

  function resetKeybinds() {
    root.keybinds = Object.assign({}, root.defaultKeybinds)
    root.tileKeys = root.computeDefaultTileKeys()
    root.saveKeybinds()
  }

  Component.onCompleted: root.loadKeybinds()

  Process {
    id: keybindsLoadProcess
    command: ["bash", "-c", "cat " + JSON.stringify(root.keybindsPath()) + " 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyLoadedKeybinds(text)
    }
  }

  Process { id: keybindsSaveProcess }

  property int settingsIndex: 0

  function settingsActions() {
    var actions = ["up", "down", "left", "right", "activate", "search"]
    root.tiles.forEach(function(tile) { actions.push("tile:" + tile.view) })
    return actions
  }

  function settingsLabel(action) {
    switch (action) {
      case "up": return "Move up"
      case "down": return "Move down"
      case "left": return "Move left"
      case "right": return "Move right"
      case "activate": return "Activate / select"
      case "search": return "Search apps"
    }
    if (action.indexOf("tile:") === 0) {
      var view = action.slice(5)
      var tile = root.tiles.find(function(t) { return t.view === view })
      return "Open " + (tile ? tile.label : view)
    }
    return action
  }

  function settingsKeyFor(action) {
    if (action.indexOf("tile:") === 0) return root.tileKeys[action.slice(5)] || ""
    return root.keybinds[action] || ""
  }

  function moveSettingsSelection(delta) {
    var count = root.settingsActions().length
    root.settingsIndex = Math.max(0, Math.min(count - 1, root.settingsIndex + delta))
  }

  property int selectedIndex: 0
  property int appsSelectedIndex: 0
  property bool appsSearching: false
  property string appsQuery: ""

  function filteredApps() {
    if (!root.appsQuery) return apps.entries
    var q = root.appsQuery.toLowerCase()
    return apps.entries.filter(function(e) { return e.name.toLowerCase().indexOf(q) >= 0 })
  }

  // Selection index for hjkl navigation within a detail pane's list
  // (DNS/network rows, bluetooth devices, power profiles).
  property int paneIndex: 0

  // Which control is keyboard-focused in the Display pane; j/k cycles
  // between them, h/l adjusts the focused one's value. Scale only moves a
  // selection cursor with h/l; it's only applied on activate (Enter).
  readonly property var displayControls: ["brightness", "textsize", "scale", "nightlight"]
  property int displayFocusIndex: 0
  property int scaleSelectedIndex: 0

  // Scale presets render as a 3-column grid; up/down moves a row within it
  // (falling through to section-switching at the top/bottom edge) while
  // left/right still moves within the row.
  readonly property int scaleGridColumns: 3

  function moveScaleSelection(dy) {
    var count = disp.scalePresets.length
    var columns = root.scaleGridColumns
    var rows = Math.ceil(count / columns)
    var col = root.scaleSelectedIndex % columns
    var row = Math.floor(root.scaleSelectedIndex / columns)
    var nextRow = row + dy

    if (nextRow < 0 || nextRow >= rows) {
      root.moveDisplayFocus(dy)
      return
    }

    var rowLength = Math.min(columns, count - nextRow * columns)
    root.scaleSelectedIndex = nextRow * columns + Math.min(col, rowLength - 1)
  }

  function moveDisplayFocus(delta) {
    var count = root.displayControls.length
    root.displayFocusIndex = (root.displayFocusIndex + delta + count) % count
  }

  function activateDisplayFocus() {
    switch (root.displayControls[root.displayFocusIndex]) {
      case "scale":
        disp.setMonitorScale(disp.scalePresets[root.scaleSelectedIndex])
        break
      case "nightlight":
        disp.toggleNightlight()
        break
    }
  }

  function adjustDisplayFocus(delta) {
    switch (root.displayControls[root.displayFocusIndex]) {
      case "brightness":
        disp.setBrightness(disp.brightnessPct + delta * 5)
        break
      case "textsize": {
        var stops = disp.textSizeStops
        var idx = disp.nearestTextStopIndex(disp.textScalePx) + delta
        idx = Math.max(0, Math.min(stops.length - 1, idx))
        disp.setTextSizePx(stops[idx])
        break
      }
      case "scale": {
        var presets = disp.scalePresets
        root.scaleSelectedIndex = Math.max(0, Math.min(presets.length - 1, root.scaleSelectedIndex + delta))
        break
      }
      case "nightlight":
        disp.setNightlightTemp(disp.nightlightTemp - delta * 200)
        break
    }
  }

  // Flat, keyboard-navigable list of controls in the Audio pane: the output
  // slider, each output device, the input slider, each input device.
  property int audioFocusIndex: 0

  function audioControls() {
    var items = [{ type: "outputSlider" }]
    audio.sinks.forEach(function(s) { items.push({ type: "outputDevice", value: s }) })
    items.push({ type: "inputSlider" })
    audio.sources.forEach(function(s) { items.push({ type: "inputDevice", value: s }) })
    return items
  }

  function moveAudioFocus(delta) {
    var items = root.audioControls()
    if (items.length === 0) return
    root.audioFocusIndex = Math.max(0, Math.min(items.length - 1, root.audioFocusIndex + delta))
  }

  function adjustAudioFocus(delta) {
    var items = root.audioControls()
    var item = items[root.audioFocusIndex]
    if (!item) return
    if (item.type === "outputSlider") audio.setVolume(audio.volumePct + delta * 5)
    else if (item.type === "inputSlider") audio.setInputVolume(audio.inputVolumePct + delta * 5)
  }

  function activateAudioFocus() {
    var items = root.audioControls()
    var item = items[root.audioFocusIndex]
    if (!item) return
    switch (item.type) {
      case "outputSlider": audio.toggleMute(); break
      case "inputSlider": audio.toggleInputMute(); break
      case "outputDevice": audio.setDefaultSink(item.value.name); break
      case "inputDevice": audio.setDefaultSource(item.value.name); break
    }
  }

  function paneList() {
    switch (root.screen) {
      case "network": {
        var items = [
          { type: "dns", value: "DHCP" },
          { type: "dns", value: "Cloudflare" },
          { type: "dns", value: "Google" },
          { type: "dns", value: "Custom" }
        ]
        net.otherNetworks.forEach(function(n) {
          items.push({ type: "connect", value: n.ssid })
        })
        return items
      }
      case "bluetooth":
        return bt.devices.map(function(d) { return { type: "bt", value: d } })
      case "battery":
        return power.profiles.map(function(p) { return { type: "profile", value: p.name } })
      default:
        return []
    }
  }

  function movePane(delta) {
    var items = root.paneList()
    if (items.length === 0) return
    root.paneIndex = Math.max(0, Math.min(items.length - 1, root.paneIndex + delta))
  }

  // The network pane mixes a horizontal DNS-provider row with a vertical
  // network list below it, so left/right and up/down need to mean
  // different things depending which part of the list is focused.
  function moveNetworkPane(dx, dy) {
    var items = root.paneList()
    if (items.length === 0) return
    var dnsCount = 4
    var otherCount = items.length - dnsCount
    var idx = root.paneIndex

    if (idx < dnsCount) {
      if (dx !== 0) {
        idx = (idx + dx + dnsCount) % dnsCount
      } else if (dy > 0 && otherCount > 0) {
        idx = dnsCount
      }
    } else {
      if (dy !== 0) {
        var otherIdx = (idx - dnsCount) + dy
        if (otherIdx < 0) idx = 0
        else if (otherIdx >= otherCount) idx = items.length - 1
        else idx = dnsCount + otherIdx
      }
    }

    root.paneIndex = idx
  }

  function activatePane() {
    var items = root.paneList()
    if (items.length === 0) return
    var item = items[root.paneIndex]
    switch (item.type) {
      case "dns": net.setDns(item.value); break
      case "connect": net.connectTo(item.value); break
      case "bt": root.screen = "btdevice"; bt.showDetail(item.value); break
      case "profile": power.setProfile(item.value); break
    }
  }

  function open(payloadJson) {
    root.selectedIndex = 0
    root.screen = "grid"
    root.windowVisible = true
    root.opened = true
  }

  function close() {
    root.opened = false
    closeTimer.restart()
  }

  Timer {
    id: closeTimer
    interval: 380
    onTriggered: root.windowVisible = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "red.omadash")
    else
      root.close()
  }

  // Used before launching something that needs keyboard/pointer focus of
  // its own (an app, the emoji picker, a screenshot's region-select) — the
  // normal fade-out keeps this window's exclusive layer-shell focus mapped
  // for closeTimer's duration, which can steal focus from what we just
  // launched. Drop it synchronously instead of waiting on the animation.
  function dismissImmediate() {
    root.opened = false
    root.windowVisible = false
    closeTimer.stop()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "red.omadash")
  }

  function moveSelection(dx, dy) {
    var columns = root.gridColumns
    var rows = Math.ceil(root.tiles.length / columns)
    var col = root.selectedIndex % columns
    var row = Math.floor(root.selectedIndex / columns)

    if (dx !== 0) {
      var rowStart = row * columns
      var rowLength = Math.min(columns, root.tiles.length - rowStart)
      col = (col + dx + rowLength) % rowLength
    }
    if (dy !== 0) {
      var lastRowLength = root.tiles.length - (rows - 1) * columns
      var colHeight = col < lastRowLength ? rows : rows - 1
      row = (row + dy + colHeight) % colHeight
      var newRowLength = Math.min(columns, root.tiles.length - row * columns)
      col = Math.min(col, newRowLength - 1)
    }

    var next = row * columns + col
    if (next >= 0 && next < root.tiles.length)
      root.selectedIndex = next
  }

  function activateSelection() {
    var tile = root.tiles[root.selectedIndex]
    if (tile.view) {
      root.screen = tile.view
      root.paneIndex = 0
      root.appsSearching = false
      root.appsQuery = ""
      root.settingsIndex = 0
      root.rebindingAction = ""
      switch (tile.view) {
        case "network": net.refresh(); break
        case "bluetooth": bt.refresh(); bt.startScan(); break
        case "audio": root.audioFocusIndex = 0; audio.refresh(); break
        case "display": root.displayFocusIndex = 0; disp.refresh(); break
        case "battery": power.refresh(); break
        case "poweractions": root.powerHoldLabel = ""; root.powerConfirmAction = null; break
        case "apps": apps.refresh(); break
        case "quick": root.quickSelectedIndex = 0; break
        case "calendar": root.resetCalendarToToday(); break
      }
      return
    }
    tileProcess.command = tile.command
    tileProcess.running = true
    root.dismissImmediate()
  }

  function backOrDismiss() {
    if (root.screen === "btdevice")
      root.screen = "bluetooth"
    else if (root.screen !== "grid")
      root.screen = "grid"
    else
      root.dismiss()
  }

  Process {
    id: tileProcess
  }

  NetworkModel {
    id: net
    active: root.screen === "network" && root.opened
  }

  BluetoothModel {
    id: bt
    active: root.screen === "bluetooth" && root.opened
    detailActive: root.screen === "btdevice" && root.opened
    onDetailForgotten: root.screen = "bluetooth"
  }

  AudioModel {
    id: audio
    active: root.screen === "audio" && root.opened
  }

  DisplayModel {
    id: disp
    onStateApplied: root.scaleSelectedIndex = disp.nearestScaleIndex(disp.monitorScale)
  }

  PowerModel {
    id: power
    active: root.screen === "battery" && root.opened
  }

  AppsModel {
    id: apps
    onLaunched: root.dismissImmediate()
  }

  function moveAppSelection(delta) {
    var count = root.filteredApps().length
    if (count === 0) return
    root.appsSelectedIndex = Math.max(0, Math.min(count - 1, root.appsSelectedIndex + delta))
  }

  function activateApp() {
    var list = root.filteredApps()
    if (list.length === 0) return
    apps.launch(list[root.appsSelectedIndex])
  }

  function startAppsSearch() {
    root.appsSearching = true
    root.appsQuery = ""
    root.appsSelectedIndex = 0
  }

  function stopAppsSearch() {
    root.appsSearching = false
    root.appsQuery = ""
    root.appsSelectedIndex = 0
  }

  function appsSearchInput(text) {
    root.appsQuery = root.appsQuery + text
    root.appsSelectedIndex = 0
  }

  function appsSearchBackspace() {
    root.appsQuery = root.appsQuery.slice(0, -1)
    root.appsSelectedIndex = 0
  }

  PanelWindow {
    visible: root.windowVisible
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omadash"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Scrim: click outside the card to dismiss.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.55)
      opacity: root.opened ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: {
        if (root.powerConfirmAction) root.powerConfirmAction = null
        else if (root.powerHoldLabel) root.cancelPowerHold()
        else if (root.rebindingAction) root.rebindingAction = ""
        else if (root.screen === "apps" && root.appsSearching) root.stopAppsSearch()
        else root.backOrDismiss()
      }
      Keys.onReturnPressed: {
        if (root.rebindingAction) return
        if (root.screen === "grid") root.activateSelection()
        else if (root.screen === "apps") root.activateApp()
        else if (root.screen === "settings") root.startRebind(root.settingsActions()[root.settingsIndex])
        else if (root.screen === "display") root.activateDisplayFocus()
        else if (root.screen === "audio") root.activateAudioFocus()
        else if (root.screen === "quick") root.activateQuickSelection()
        else if (root.screen === "poweractions") { if (root.powerConfirmAction) root.confirmPowerAction(true) }
        else root.activatePane()
      }
      Keys.onEnterPressed: {
        if (root.rebindingAction) return
        if (root.screen === "grid") root.activateSelection()
        else if (root.screen === "apps") root.activateApp()
        else if (root.screen === "settings") root.startRebind(root.settingsActions()[root.settingsIndex])
        else if (root.screen === "display") root.activateDisplayFocus()
        else if (root.screen === "audio") root.activateAudioFocus()
        else if (root.screen === "quick") root.activateQuickSelection()
        else if (root.screen === "poweractions") { if (root.powerConfirmAction) root.confirmPowerAction(true) }
        else root.activatePane()
      }
      Keys.onReleased: (event) => {
        if (root.screen !== "poweractions" || event.isAutoRepeat) return
        var t = (event.text || "").toLowerCase()
        if (root.powerHoldLabel && root.powerKeys[root.powerHoldLabel] === t) {
          root.releasePowerHold()
          event.accepted = true
        }
      }
      Keys.onPressed: (event) => {
        // Capturing a new key for a rebound action takes priority over
        // everything else (Esc to cancel is handled above).
        if (root.rebindingAction) {
          if (event.text && event.text.length === 1 && event.key !== Qt.Key_Escape) {
            root.applyRebind(event.text.toLowerCase())
          }
          event.accepted = true
          return
        }

        if (root.screen === "apps" && root.appsSearching) {
          if (event.key === Qt.Key_Backspace) { root.appsSearchBackspace(); event.accepted = true }
          else if (event.text && event.text.length > 0 && event.text >= " ") { root.appsSearchInput(event.text); event.accepted = true }
          return
        }

        var kb = root.keybinds
        var t = (event.text || "").toLowerCase()

        switch (root.screen) {
          case "grid":
            if (t === kb.left) { root.moveSelection(-1, 0); event.accepted = true }
            else if (t === kb.right) { root.moveSelection(1, 0); event.accepted = true }
            else if (t === kb.up) { root.moveSelection(0, -1); event.accepted = true }
            else if (t === kb.down) { root.moveSelection(0, 1); event.accepted = true }
            else if (t === "s") {
              root.screen = "settings"
              root.settingsIndex = 0
              root.rebindingAction = ""
              event.accepted = true
            } else {
              var tileIdx = root.tiles.findIndex(function(tl) { return root.tileKeys[tl.view] === t })
              if (tileIdx >= 0) {
                root.selectedIndex = tileIdx
                root.activateSelection()
                event.accepted = true
              }
            }
            break
          case "apps":
            if (event.text === kb.search) { root.startAppsSearch(); event.accepted = true }
            else if (t === kb.activate) { root.activateApp(); event.accepted = true }
            else if (t === kb.up) { root.moveAppSelection(-1); event.accepted = true }
            else if (t === kb.down) { root.moveAppSelection(1); event.accepted = true }
            break
          case "network":
            if (t === kb.activate) { root.activatePane(); event.accepted = true }
            else if (t === kb.up) { root.moveNetworkPane(0, -1); event.accepted = true }
            else if (t === kb.down) { root.moveNetworkPane(0, 1); event.accepted = true }
            else if (t === kb.left) { root.moveNetworkPane(-1, 0); event.accepted = true }
            else if (t === kb.right) { root.moveNetworkPane(1, 0); event.accepted = true }
            break
          case "bluetooth":
            if (t === kb.activate) { root.activatePane(); event.accepted = true }
            else if (t === kb.up) { root.movePane(-1); event.accepted = true }
            else if (t === kb.down) { root.movePane(1); event.accepted = true }
            break
          case "battery":
            if (t === kb.activate) { root.activatePane(); event.accepted = true }
            else if (t === kb.left) { root.movePane(-1); event.accepted = true }
            else if (t === kb.right) { root.movePane(1); event.accepted = true }
            break
          case "poweractions":
            if (root.powerConfirmAction) {
              if (t === "y" || t === kb.activate) { root.confirmPowerAction(true); event.accepted = true }
              else if (t === "n") { root.confirmPowerAction(false); event.accepted = true }
              break
            }
            if (!event.isAutoRepeat) {
              var heldAction = root.powerActions.find(function(a) { return root.powerKeys[a.label] === t })
              if (heldAction) { root.startPowerHold(heldAction.label); event.accepted = true }
            } else if (root.powerActions.some(function(a) { return root.powerKeys[a.label] === t })) {
              event.accepted = true
            }
            break
          case "quick":
            if (t === kb.left) { root.moveQuickSelection(-1, 0); event.accepted = true }
            else if (t === kb.right) { root.moveQuickSelection(1, 0); event.accepted = true }
            else if (t === kb.up) { root.moveQuickSelection(0, -1); event.accepted = true }
            else if (t === kb.down) { root.moveQuickSelection(0, 1); event.accepted = true }
            else if (t === kb.activate) { root.activateQuickSelection(); event.accepted = true }
            else {
              var quickIdx = root.quickActions.findIndex(function(a) { return root.quickKeys[a.label] === t })
              if (quickIdx >= 0) {
                root.quickSelectedIndex = quickIdx
                root.activateQuickSelection()
                event.accepted = true
              }
            }
            break
          case "calendar":
            if (t === kb.left) { root.moveCalendarDay(-1); event.accepted = true }
            else if (t === kb.right) { root.moveCalendarDay(1); event.accepted = true }
            else if (t === kb.up) { root.moveCalendarDay(-7); event.accepted = true }
            else if (t === kb.down) { root.moveCalendarDay(7); event.accepted = true }
            break
          case "audio":
            if (t === kb.up) { root.moveAudioFocus(-1); event.accepted = true }
            else if (t === kb.down) { root.moveAudioFocus(1); event.accepted = true }
            else if (t === kb.right) { root.adjustAudioFocus(1); event.accepted = true }
            else if (t === kb.left) { root.adjustAudioFocus(-1); event.accepted = true }
            else if (t === kb.activate) { root.activateAudioFocus(); event.accepted = true }
            break
          case "display":
            if (t === kb.up) {
              if (root.displayControls[root.displayFocusIndex] === "scale") root.moveScaleSelection(-1)
              else root.moveDisplayFocus(-1)
              event.accepted = true
            } else if (t === kb.down) {
              if (root.displayControls[root.displayFocusIndex] === "scale") root.moveScaleSelection(1)
              else root.moveDisplayFocus(1)
              event.accepted = true
            } else if (t === kb.right) { root.adjustDisplayFocus(1); event.accepted = true }
            else if (t === kb.left) { root.adjustDisplayFocus(-1); event.accepted = true }
            else if (t === kb.activate) { root.activateDisplayFocus(); event.accepted = true }
            break
          case "settings":
            if (t === kb.up) { root.moveSettingsSelection(-1); event.accepted = true }
            else if (t === kb.down) { root.moveSettingsSelection(1); event.accepted = true }
            else if (t === kb.activate) { root.startRebind(root.settingsActions()[root.settingsIndex]); event.accepted = true }
            break
          case "btdevice":
            if (t === kb.activate) { bt.toggleConnect(bt.detail); event.accepted = true }
            else if (t === "f") { bt.forget(bt.detail); event.accepted = true }
            break
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: {
          switch (root.screen) {
            case "network": return 340
            case "bluetooth": return 320
            case "audio": return 320
            case "display": return 320
            case "battery": return 320
            case "poweractions": return 300
            case "quick": return 300
            case "calendar": return 320
            case "apps": return 320
            case "settings": return 320
            case "btdevice": return 300
            default: return 320
          }
        }
        height: {
          switch (root.screen) {
            case "network": return 520
            case "bluetooth": return 340
            case "audio": return 340
            case "display": return 420
            case "battery": return 300
            case "poweractions": return 260
            case "quick": return 300
            case "calendar": return 380
            case "apps": return 420
            case "settings": return 420
            case "btdevice": return 300
            default: return 280
          }
        }
        radius: 12
        color: "#1e1e2e"
        border.width: 0
        clip: true

        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.8
        transformOrigin: Item.Center

        Behavior on opacity {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          NumberAnimation {
            duration: 380
            easing.type: root.opened ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.6
          }
        }
        Behavior on width {
          NumberAnimation { duration: 320; easing.type: Easing.InOutCubic }
        }
        Behavior on height {
          NumberAnimation { duration: 320; easing.type: Easing.InOutCubic }
        }

        // Swallow clicks on the card so only the scrim dismisses.
        MouseArea { anchors.fill: parent; onClicked: {} }

        TileGridView { root: root }
        NetworkView { root: root; net: net }
        BluetoothView { root: root; bt: bt }
        BluetoothDeviceView { root: root; bt: bt }
        AudioView { root: root; audio: audio }
        DisplayView { root: root; disp: disp }
        BatteryView { root: root; power: power }
        PowerActionsView { root: root }
        QuickView { root: root }
        CalendarView { root: root }
        AppsView { root: root; apps: apps }
        SettingsView { root: root }
      }
    }
  }
}
