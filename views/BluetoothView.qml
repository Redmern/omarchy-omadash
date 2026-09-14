import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var bt

          anchors.fill: parent
          anchors.margins: 16
          spacing: 10
          opacity: root.screen === "bluetooth" ? 1 : 0
          enabled: root.screen === "bluetooth"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }
            Text { text: "Bluetooth"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }

            Rectangle {
              width: 40
              height: 22
              radius: 11
              color: bt.powered ? "#89b4fa" : "#45475a"
              Behavior on color { ColorAnimation { duration: 150 } }

              Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#1e1e2e"
                anchors.verticalCenter: parent.verticalCenter
                x: bt.powered ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 150 } }
              }

              MouseArea { anchors.fill: parent; onClicked: bt.togglePower() }
            }

            PaneHint { root: view.root; screenName: "bluetooth" }
          }

          Text {
            visible: root.isHintVisible("bluetooth")
            text: root.hintText("bluetooth")
            color: "#6c7086"
            font.pixelSize: 9
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          Text {
            text: bt.scanning ? "DEVICES · SCANNING…" : "DEVICES"
            color: "#a6adc8"
            font.pixelSize: 9
          }

          ListView {
            id: btDeviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: bt.devices
            currentIndex: root.screen === "bluetooth" ? root.paneIndex : -1
            highlightMoveDuration: 100

            delegate: Rectangle {
              id: btRow
              required property int index
              required property var modelData
              width: btDeviceList.width
              height: 32
              radius: 6
              color: modelData.connected ? "#45475a" : "transparent"
              border.width: root.screen === "bluetooth" && root.paneIndex === index ? 2 : 0
              border.color: "#f9e2af"

              RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                Text { text: ""; font.family: "Symbols Nerd Font"; color: "#cdd6f4"; font.pixelSize: 12 }
                Text { text: btRow.modelData.name; color: "#cdd6f4"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                Text {
                  text: btRow.modelData.connected ? "Connected" : (btRow.modelData.paired ? "Connect" : "Pair")
                  color: btRow.modelData.connected ? "#a6adc8" : "#89b4fa"
                  font.pixelSize: 9
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: { root.paneIndex = btRow.index; root.screen = "btdevice"; bt.showDetail(btRow.modelData) }
              }
            }
          }
}
