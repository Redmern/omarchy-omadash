import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var disp

          anchors.fill: parent
          anchors.margins: 16
          spacing: 12
          opacity: root.screen === "display" ? 1 : 0
          enabled: root.screen === "display"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }
            ColumnLayout {
              spacing: 0
              Text { text: "Display"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true }
              Text { text: disp.monitorName || ""; color: "#a6adc8"; font.pixelSize: 9 }
            }

            Item { Layout.fillWidth: true }

            PaneHint { root: view.root; screenName: "display" }
          }

          Text {
            visible: root.isHintVisible("display")
            text: root.hintText("display")
            color: "#6c7086"
            font.pixelSize: 9
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "BRIGHTNESS" + (root.isHintVisible("display") ? " (" + root.displayKeyFor("brightness").toUpperCase() + ")" : "")
                color: root.screen === "display" && root.displayFocusIndex === 0 ? "#f9e2af" : "#a6adc8"
                font.pixelSize: 9
              }
              Item { Layout.fillWidth: true }
              Text { text: Math.round(disp.brightnessPct) + "%"; color: "#a6adc8"; font.pixelSize: 9 }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#313244"
              border.width: root.screen === "display" && root.displayFocusIndex === 0 ? 1 : 0
              border.color: "#f9e2af"

              Rectangle {
                width: parent.width * (disp.brightnessPct / 100)
                height: parent.height
                radius: 3
                color: "#89b4fa"
                Behavior on width { NumberAnimation { duration: 120 } }
              }

              MouseArea {
                anchors.fill: parent
                onPositionChanged: if (pressed) disp.setBrightness(mouseX / width * 100)
                onClicked: disp.setBrightness(mouseX / width * 100)
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "TEXT SIZE" + (root.isHintVisible("display") ? " (" + root.displayKeyFor("textsize").toUpperCase() + ")" : "")
                color: root.screen === "display" && root.displayFocusIndex === 1 ? "#f9e2af" : "#a6adc8"
                font.pixelSize: 9
              }
              Item { Layout.fillWidth: true }
              Text { text: disp.textScalePx + "px"; color: "#a6adc8"; font.pixelSize: 9 }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#313244"
              border.width: root.screen === "display" && root.displayFocusIndex === 1 ? 1 : 0
              border.color: "#f9e2af"

              Rectangle {
                width: parent.width * (disp.nearestTextStopIndex(disp.textScalePx) / (disp.textSizeStops.length - 1))
                height: parent.height
                radius: 3
                color: "#89b4fa"
                Behavior on width { NumberAnimation { duration: 120 } }
              }

              function stopIndexAt(px) {
                var frac = Math.max(0, Math.min(1, px / width))
                return Math.round(frac * (disp.textSizeStops.length - 1))
              }

              MouseArea {
                anchors.fill: parent
                onPositionChanged: if (pressed) disp.setTextSizePx(disp.textSizeStops[parent.stopIndexAt(mouseX)])
                onClicked: disp.setTextSizePx(disp.textSizeStops[parent.stopIndexAt(mouseX)])
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 6

            Text {
              text: "SCALE" + (root.isHintVisible("display") ? " (" + root.displayKeyFor("scale").toUpperCase() + ")" : "")
              color: root.screen === "display" && root.displayFocusIndex === 2 ? "#f9e2af" : "#a6adc8"
              font.pixelSize: 9
            }

            GridLayout {
              columns: 3
              columnSpacing: 6
              rowSpacing: 6
              Layout.fillWidth: true

              Repeater {
                model: disp.scalePresets

                Rectangle {
                  id: scaleBtn
                  required property int index
                  required property real modelData
                  Layout.fillWidth: true
                  height: 26
                  radius: 6
                  color: Math.abs(disp.monitorScale - modelData) < 0.01 ? "#89b4fa" : "#313244"
                  border.width: root.screen === "display" && root.displayFocusIndex === 2 && root.scaleSelectedIndex === index ? 2 : 0
                  border.color: "#f9e2af"

                  Text {
                    anchors.centerIn: parent
                    text: scaleBtn.modelData + "x"
                    color: Math.abs(disp.monitorScale - scaleBtn.modelData) < 0.01 ? "#1e1e2e" : "#cdd6f4"
                    font.pixelSize: 10
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: { root.scaleSelectedIndex = scaleBtn.index; disp.setMonitorScale(scaleBtn.modelData) }
                  }
                }
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              spacing: 10

              Text {
                text: ""
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: root.screen === "display" && root.displayFocusIndex === 3 ? "#f9e2af" : "#89b4fa"
              }
              Text {
                text: "Night Light" + (root.isHintVisible("display") ? " (" + root.displayKeyFor("nightlight").toUpperCase() + ")" : "")
                color: root.screen === "display" && root.displayFocusIndex === 3 ? "#f9e2af" : "#cdd6f4"
                font.pixelSize: 11
                Layout.fillWidth: true
              }

              Rectangle {
                width: 40
                height: 22
                radius: 11
                color: disp.nightlightOn ? "#89b4fa" : "#45475a"
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                  width: 18
                  height: 18
                  radius: 9
                  color: "#1e1e2e"
                  anchors.verticalCenter: parent.verticalCenter
                  x: disp.nightlightOn ? parent.width - width - 2 : 2
                  Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea { anchors.fill: parent; onClicked: disp.toggleNightlight() }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Text { text: "INTENSITY"; color: "#a6adc8"; font.pixelSize: 9 }
              Item { Layout.fillWidth: true }
              Text {
                text: disp.nightlightOn ? Math.round((6500 - disp.nightlightTemp) / 4000 * 100) + "%" : "OFF"
                color: "#a6adc8"
                font.pixelSize: 9
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#313244"
              opacity: disp.nightlightOn ? 1 : 0.4
              border.width: root.screen === "display" && root.displayFocusIndex === 3 ? 1 : 0
              border.color: "#f9e2af"

              Rectangle {
                width: parent.width * ((6500 - disp.nightlightTemp) / 4000)
                height: parent.height
                radius: 3
                color: "#f9a05a"
                Behavior on width { NumberAnimation { duration: 120 } }
              }

              MouseArea {
                anchors.fill: parent
                onPositionChanged: if (pressed) disp.setNightlightTemp(6500 - (mouseX / width) * 4000)
                onClicked: disp.setNightlightTemp(6500 - (mouseX / width) * 4000)
              }
            }
          }
}
