import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var bt

          anchors.fill: parent
          anchors.margins: 16
          spacing: 12
          opacity: root.screen === "btdevice" ? 1 : 0
          enabled: root.screen === "btdevice"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text {
                text: bt.detail.name || ""
                color: "#f4f4f8"
                font.pixelSize: 15
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                text: bt.detail.connected ? "CONNECTED" : (bt.detail.paired ? "PAIRED" : "NOT PAIRED")
                color: "#a6adc8"
                font.pixelSize: 9
              }
            }
          }

          GridLayout {
            columns: 2
            columnSpacing: 16
            rowSpacing: 6
            Layout.fillWidth: true
            visible: bt.detail.battery !== undefined && bt.detail.battery >= 0

            ColumnLayout {
              spacing: 1
              Text { text: "BATTERY"; color: "#a6adc8"; font.pixelSize: 9 }
              Text { text: (bt.detail.battery || 0) + "%"; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
            }
            ColumnLayout {
              spacing: 1
              Text { text: "TRUSTED"; color: "#a6adc8"; font.pixelSize: 9 }
              Text { text: bt.detail.trusted ? "Yes" : "No"; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
            }
          }

          Text { text: "ADDRESS"; color: "#a6adc8"; font.pixelSize: 9 }
          Text { text: bt.detail.mac || ""; color: "#cdd6f4"; font.pixelSize: 11 }

          Item { Layout.fillHeight: true }

          Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 6
            color: bt.detail.connected ? "#45475a" : "#89b4fa"

            Text {
              anchors.centerIn: parent
              text: bt.detail.connected ? "Disconnect" : (bt.detail.paired ? "Connect" : "Pair")
              color: bt.detail.connected ? "#cdd6f4" : "#1e1e2e"
              font.pixelSize: 11
              font.bold: true
            }

            MouseArea { anchors.fill: parent; onClicked: bt.toggleConnect(bt.detail) }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 26
            radius: 6
            color: "#313244"
            visible: !!bt.detail.paired

            Text {
              anchors.centerIn: parent
              text: "Forget device"
              color: "#f38ba8"
              font.pixelSize: 11
            }

            MouseArea { anchors.fill: parent; onClicked: bt.forget(bt.detail) }
          }
}
