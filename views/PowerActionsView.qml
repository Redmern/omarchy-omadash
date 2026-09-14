import QtQuick
import QtQuick.Layouts

// Destructive system actions. Hold a tile's key for root.powerHoldMs to run
// it right away (the fill animation shows progress); release early instead
// raises a yes/no confirmation.
Item {
  id: view
  property var root

  anchors.fill: parent
  opacity: root.screen === "poweractions" ? 1 : 0
  enabled: root.screen === "poweractions"

  Behavior on opacity {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }
      Text { text: "Power"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
    }

    Text {
      text: "Hold a tile's key to run it — tap to ask first"
      color: "#6c7086"
      font.pixelSize: 9
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    GridLayout {
      columns: 3
      columnSpacing: 8
      rowSpacing: 8
      Layout.fillWidth: true
      Layout.fillHeight: true

      Repeater {
        model: root.powerActions

        Rectangle {
          id: actionTile
          required property int index
          required property var modelData
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 8
          color: "#313244"
          clip: true

          // Fill grows left-to-right as the key is held.
          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * (root.powerHoldLabel === actionTile.modelData.label ? root.powerHoldProgress : 0)
            radius: 8
            color: "#f38ba8"
          }

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
              text: actionTile.modelData.icon
              font.family: "Symbols Nerd Font"
              font.pixelSize: 16
              color: "#cdd6f4"
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: actionTile.modelData.label
              color: "#cdd6f4"
              font.pixelSize: 10
              Layout.alignment: Qt.AlignHCenter
            }
          }

          Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            text: (root.powerKeys[actionTile.modelData.label] || "").toUpperCase()
            color: "#6c7086"
            font.pixelSize: 9
          }

          MouseArea {
            anchors.fill: parent
            onPressed: root.startPowerHold(actionTile.modelData.label)
            onReleased: root.releasePowerHold()
            onCanceled: root.cancelPowerHold()
          }
        }
      }
    }
  }

  // Yes/no confirmation after a tap that didn't hold long enough.
  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Qt.rgba(0.12, 0.12, 0.16, 0.96)
    visible: root.powerConfirmAction !== null

    ColumnLayout {
      anchors.centerIn: parent
      spacing: 12
      width: parent.width - 32

      Text {
        text: root.powerConfirmAction ? ("Run “" + root.powerConfirmAction.label + "”?") : ""
        color: "#f4f4f8"
        font.pixelSize: 13
        font.bold: true
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 10

        Rectangle {
          width: 70
          height: 30
          radius: 6
          color: "#f38ba8"
          Text { anchors.centerIn: parent; text: "Yes (y)"; color: "#1e1e2e"; font.pixelSize: 11; font.bold: true }
          MouseArea { anchors.fill: parent; onClicked: root.confirmPowerAction(true) }
        }

        Rectangle {
          width: 70
          height: 30
          radius: 6
          color: "#313244"
          Text { anchors.centerIn: parent; text: "No (n)"; color: "#cdd6f4"; font.pixelSize: 11 }
          MouseArea { anchors.fill: parent; onClicked: root.confirmPowerAction(false) }
        }
      }
    }
  }
}
