import QtQuick
import QtQuick.Layouts

// Small info icon + keybind badge shown in a pane's header. Click (or press
// root.keybinds.hint) toggles that pane's hint line on/off.
RowLayout {
  id: view
  property var root
  property string screenName
  spacing: 4

  Text {
    text: ""
    font.family: "Symbols Nerd Font"
    font.pixelSize: 12
    color: root.isHintVisible(view.screenName) ? "#89b4fa" : "#6c7086"
  }

  Rectangle {
    width: keyLabel.implicitWidth + 8
    height: 16
    radius: 4
    color: "#313244"

    Text {
      id: keyLabel
      anchors.centerIn: parent
      text: (root.keybinds.hint || "").toUpperCase()
      color: "#6c7086"
      font.pixelSize: 8
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.toggleHint(view.screenName)
  }
}
