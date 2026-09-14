import QtQuick
import QtQuick.Layouts

// Small non-destructive command tiles: run immediately and dismiss.
ColumnLayout {
  id: view
  property var root

  anchors.fill: parent
  anchors.margins: 16
  spacing: 12
  opacity: root.screen === "quick" ? 1 : 0
  enabled: root.screen === "quick"

  Behavior on opacity {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }
    Text { text: "Quick Actions"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }

    PaneHint { root: view.root; screenName: "quick" }
  }

  Text {
    visible: root.hintHeld
    text: root.hintText("quick")
    color: "#6c7086"
    font.pixelSize: 9
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  GridLayout {
    columns: root.quickColumns
    columnSpacing: 8
    rowSpacing: 8
    Layout.fillWidth: true
    Layout.fillHeight: true

    Repeater {
      model: root.quickActions

      Rectangle {
        id: quickTile
        required property int index
        required property var modelData
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 8
        color: root.quickSelectedIndex === index ? "#45475a" : "#313244"
        border.width: root.quickSelectedIndex === index ? 2 : 0
        border.color: "#89b4fa"

        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 4

          Text {
            text: quickTile.modelData.icon
            font.family: "Symbols Nerd Font"
            font.pixelSize: 18
            color: "#cdd6f4"
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: quickTile.modelData.label
            color: "#cdd6f4"
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
          }
        }

        Text {
          visible: root.isHintVisible("quick")
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: 4
          text: (root.quickKeys[quickTile.modelData.label] || "").toUpperCase()
          color: "#6c7086"
          font.pixelSize: 9
        }

        MouseArea {
          anchors.fill: parent
          onClicked: {
            root.quickSelectedIndex = quickTile.index
            root.activateQuickSelection()
          }
        }
      }
    }
  }
}
