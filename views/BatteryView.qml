import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var power

  anchors.fill: parent
  anchors.margins: 16
  spacing: 12
  opacity: root.screen === "battery" ? 1 : 0
  enabled: root.screen === "battery"

  Behavior on opacity {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }

    ColumnLayout {
      spacing: 0
      Text { text: "Battery"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true }
      Text { text: power.statusLabel(); color: "#a6adc8"; font.pixelSize: 9 }
    }

    Text { text: power.percent + "%"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true }

    Item { Layout.fillWidth: true }

    PaneHint { root: view.root; screenName: "battery" }
  }

  Text {
    visible: root.hintHeld
    text: root.hintText("battery")
    color: "#6c7086"
    font.pixelSize: 9
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  Rectangle {
    Layout.fillWidth: true
    height: 6
    radius: 3
    color: "#313244"

    Rectangle {
      width: parent.width * (power.percent / 100)
      height: parent.height
      radius: 3
      color: "#89b4fa"
      Behavior on width { NumberAnimation { duration: 120 } }
    }
  }

  GridLayout {
    columns: 2
    columnSpacing: 16
    rowSpacing: 6
    Layout.fillWidth: true

    ColumnLayout {
      spacing: 1
      Text { text: "BATTERY SIZE"; color: "#a6adc8"; font.pixelSize: 9 }
      Text { text: power.energyFullWh.toFixed(0) + "Wh"; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
    }
    ColumnLayout {
      spacing: 1
      Text { text: power.state === "discharging" ? "TIME TO EMPTY" : "TIME TO FULL"; color: "#a6adc8"; font.pixelSize: 9 }
      Text { text: power.timeLabel; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
    }
    ColumnLayout {
      spacing: 1
      Text { text: "CHARGE CYCLES"; color: "#a6adc8"; font.pixelSize: 9 }
      Text { text: power.chargeCycles; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
    }
    ColumnLayout {
      spacing: 1
      Text { text: "CHARGING"; color: "#a6adc8"; font.pixelSize: 9 }
      Text { text: power.state === "charging" ? "Yes" : "No"; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
    }
  }

  Text { text: "POWER PROFILE"; color: "#a6adc8"; font.pixelSize: 9 }

  RowLayout {
    Layout.fillWidth: true
    Layout.fillHeight: false
    spacing: 6

    Repeater {
      model: power.profiles

      Rectangle {
        id: profileRow
        required property int index
        required property var modelData
        Layout.fillWidth: true
        height: 46
        radius: 6
        color: modelData.active ? "#89b4fa" : "#313244"
        border.width: root.screen === "battery" && root.paneIndex === index ? 2 : 0
        border.color: "#f9e2af"

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 2

          Text {
            text: {
              switch (profileRow.modelData.name) {
                case "power-saver": return ""
                case "performance": return ""
                default: return ""
              }
            }
            font.family: "Symbols Nerd Font"
            font.pixelSize: 14
            color: profileRow.modelData.active ? "#1e1e2e" : "#cdd6f4"
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: profileRow.modelData.name
            color: profileRow.modelData.active ? "#1e1e2e" : "#cdd6f4"
            font.pixelSize: 9
            Layout.alignment: Qt.AlignHCenter
          }
        }

        Text {
          visible: root.isHintVisible("battery")
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: 4
          text: (root.profileKeys[profileRow.modelData.name] || "").toUpperCase()
          color: profileRow.modelData.active ? "#1e1e2e" : "#6c7086"
          font.pixelSize: 9
        }

        MouseArea {
          anchors.fill: parent
          onClicked: { root.paneIndex = profileRow.index; power.setProfile(profileRow.modelData.name) }
        }
      }
    }
  }
}
