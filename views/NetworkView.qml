import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var net

          anchors.fill: parent
          anchors.margins: 16
          spacing: 12
          opacity: root.screen === "network" ? 1 : 0
          enabled: root.screen === "network"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: ""
              font.family: "Symbols Nerd Font"
              font.pixelSize: 20
              color: "#89b4fa"
            }

            ColumnLayout {
              spacing: 0
              Text {
                text: net.ssid || "Not connected"
                color: "#f4f4f8"
                font.pixelSize: 15
                font.bold: true
              }
              Text {
                text: net.pingMs ? "CONNECTED" : "DISCONNECTED"
                color: "#a6adc8"
                font.pixelSize: 9
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              visible: root.isHintVisible("network")
              text: (root.wifiPowerKey || "").toUpperCase()
              color: "#6c7086"
              font.pixelSize: 9
            }

            PaneHint { root: view.root; screenName: "network" }

            Rectangle {
              width: 40
              height: 22
              radius: 11
              color: net.radioOn ? "#89b4fa" : "#45475a"
              border.width: root.screen === "network" && root.paneIndex === 0 ? 2 : 0
              border.color: "#f9e2af"

              Behavior on color { ColorAnimation { duration: 150 } }

              Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#1e1e2e"
                anchors.verticalCenter: parent.verticalCenter
                x: net.radioOn ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 150 } }
              }

              MouseArea { anchors.fill: parent; onClicked: { root.paneIndex = 0; net.toggleRadio() } }
            }
          }

          Text {
            visible: root.hintHeld
            text: root.hintText("network")
            color: "#6c7086"
            font.pixelSize: 9
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          GridLayout {
            columns: 2
            columnSpacing: 16
            rowSpacing: 6
            Layout.fillWidth: true

            Repeater {
              model: [
                { label: "PING", value: net.pingMs ? net.pingMs + " ms" : "—" },
                { label: "PACKET LOSS", value: net.lossPct + "%" },
                { label: "RECEIVING", value: net.rxRateKBs.toFixed(1) + " KB/s" },
                { label: "SENDING", value: net.txRateKBs.toFixed(1) + " KB/s" },
                { label: "DOWNLOADED", value: net.formatBytes(net.rxBytes) },
                { label: "UPLOADED", value: net.formatBytes(net.txBytes) },
                { label: "IP ADDRESS", value: net.ip || "—" },
                { label: "GATEWAY", value: net.gateway || "—" }
              ]

              ColumnLayout {
                required property var modelData
                spacing: 1
                Text { text: modelData.label; color: "#a6adc8"; font.pixelSize: 9 }
                Text { text: modelData.value; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Text { text: "WI-FI BAND: " + net.bandLabel(); color: "#a6adc8"; font.pixelSize: 10 }
          }

          Text { text: "DNS PROVIDER"; color: "#a6adc8"; font.pixelSize: 9 }

          RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
              model: ["DHCP", "Cloudflare", "Google", "Custom"]

              Rectangle {
                id: dnsBtn
                required property int index
                required property string modelData
                Layout.fillWidth: true
                height: 26
                radius: 6
                color: net.dns === modelData ? "#89b4fa" : "#313244"
                border.width: root.screen === "network" && root.paneIndex === index + 1 ? 2 : 0
                border.color: "#f9e2af"

                Text {
                  anchors.centerIn: parent
                  text: parent.modelData
                  color: net.dns === parent.modelData ? "#1e1e2e" : "#cdd6f4"
                  font.pixelSize: 10
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: { root.paneIndex = dnsBtn.index + 1; net.setDns(dnsBtn.modelData) }
                }
              }
            }
          }

          Text { text: "KNOWN NETWORKS"; color: "#a6adc8"; font.pixelSize: 9 }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
              model: net.ssid ? [net.ssid].concat(net.knownNetworks.filter(function(n) { return n !== net.ssid })) : net.knownNetworks

              Rectangle {
                required property string modelData
                Layout.fillWidth: true
                height: 30
                radius: 6
                color: modelData === net.ssid ? "#45475a" : "transparent"

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 6
                  Text { text: ""; font.family: "Symbols Nerd Font"; color: "#cdd6f4"; font.pixelSize: 12 }
                  Text { text: parent.parent.modelData; color: "#cdd6f4"; font.pixelSize: 11; Layout.fillWidth: true }
                  Text {
                    visible: parent.parent.modelData === net.ssid
                    text: "Connected"
                    color: "#a6adc8"
                    font.pixelSize: 9
                  }
                }
              }
            }
          }

          Text { text: "OTHER NETWORKS"; color: "#a6adc8"; font.pixelSize: 9 }

          ListView {
            id: otherNetworksList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: net.otherNetworks
            currentIndex: root.screen === "network" && root.paneIndex >= 5 ? root.paneIndex - 5 : -1
            highlightMoveDuration: 100

            delegate: Rectangle {
              id: otherRow
              required property int index
              required property var modelData
              width: otherNetworksList.width
              height: 28
              radius: 6
              color: "transparent"
              border.width: root.screen === "network" && root.paneIndex === index + 5 ? 2 : 0
              border.color: "#f9e2af"

              RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                Text { text: ""; font.family: "Symbols Nerd Font"; color: "#a6adc8"; font.pixelSize: 11 }
                Text { text: otherRow.modelData.ssid; color: "#cdd6f4"; font.pixelSize: 11; Layout.fillWidth: true }
                Text {
                  visible: otherRow.modelData.secured
                  text: ""
                  font.family: "Symbols Nerd Font"
                  color: "#a6adc8"
                  font.pixelSize: 10
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: { root.paneIndex = otherRow.index + 5; net.connectTo(otherRow.modelData.ssid) }
              }
            }
          }
}
