import QtQuick
import QtQuick.Layouts

// Small info icon + keybind badge shown in a pane's header. Hold down (mouse
// or root.keybinds.hint) to show that pane's hint line; release to hide it.
//
// Root is a plain Item (not a Layout) so the MouseArea below can anchor.fill
// it without fighting the outer RowLayout that positions this component.
Item {
  id: view
  property var root
  property string screenName
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.fill: parent
    spacing: 4

    Text {
      text: ""
      font.family: "Symbols Nerd Font"
      font.pixelSize: 12
      color: "#89b4fa"
    }

    Rectangle {
      width: keyLabel.implicitWidth + 8
      height: 16
      radius: 4
      color: "#313244"

      Text {
        id: keyLabel
        anchors.centerIn: parent
        text: (view.root.keybinds.hint || "").toUpperCase()
        color: "#6c7086"
        font.pixelSize: 8
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    onPressed: view.root.hintHeld = true
    onReleased: view.root.hintHeld = false
    onCanceled: view.root.hintHeld = false
  }
}
