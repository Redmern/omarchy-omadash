import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var audio

          anchors.fill: parent
          anchors.margins: 16
          spacing: 14
          opacity: root.screen === "audio" ? 1 : 0
          enabled: root.screen === "audio"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              text: audio.muted ? "" : ""
              font.family: "Symbols Nerd Font"
              font.pixelSize: 20
              color: "#89b4fa"
            }

            ColumnLayout {
              spacing: 0
              Layout.fillWidth: true
              Text { text: "Audio"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true }
              Text {
                text: audio.muted ? "MUTED" : Math.round(audio.volumePct) + "%"
                color: "#a6adc8"
                font.pixelSize: 9
              }
            }

            Rectangle {
              width: 40
              height: 22
              radius: 11
              color: audio.muted ? "#89b4fa" : "#45475a"
              Behavior on color { ColorAnimation { duration: 150 } }

              Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#1e1e2e"
                anchors.verticalCenter: parent.verticalCenter
                x: audio.muted ? parent.width - width - 2 : 2
                Behavior on x { NumberAnimation { duration: 150 } }
              }

              MouseArea { anchors.fill: parent; onClicked: audio.toggleMute() }
            }

            PaneHint { root: view.root; screenName: "audio" }
          }

          Text {
            visible: root.isHintVisible("audio")
            text: root.hintText("audio")
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
                text: "OUTPUT"
                color: root.screen === "audio" && root.audioFocusIndex === 0 ? "#f9e2af" : "#a6adc8"
                font.pixelSize: 9
              }
              Item { Layout.fillWidth: true }
              Text { text: Math.round(audio.volumePct) + "%"; color: "#a6adc8"; font.pixelSize: 9 }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#313244"
              border.width: root.screen === "audio" && root.audioFocusIndex === 0 ? 1 : 0
              border.color: "#f9e2af"

              Rectangle {
                width: parent.width * (audio.volumePct / 100)
                height: parent.height
                radius: 3
                color: "#89b4fa"
                Behavior on width { NumberAnimation { duration: 120 } }
              }

              MouseArea {
                anchors.fill: parent
                onPositionChanged: if (pressed) audio.setVolume(mouseX / width * 100)
                onClicked: audio.setVolume(mouseX / width * 100)
              }
            }

            Repeater {
              model: audio.sinks

              Rectangle {
                id: sinkRow
                required property int index
                required property var modelData
                Layout.fillWidth: true
                height: 32
                radius: 6
                color: modelData.active ? "#45475a" : "#313244"
                border.width: root.screen === "audio" && root.audioFocusIndex === index + 1 ? 2 : 0
                border.color: "#f9e2af"

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 8
                  Text {
                    text: ""
                    font.family: "Symbols Nerd Font"
                    color: sinkRow.modelData.active ? "#89b4fa" : "#a6adc8"
                    font.pixelSize: 12
                  }
                  Text { text: sinkRow.modelData.label; color: "#cdd6f4"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                  Text {
                    visible: sinkRow.modelData.active
                    text: ""
                    font.family: "Symbols Nerd Font"
                    color: "#89b4fa"
                    font.pixelSize: 10
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: { root.audioFocusIndex = sinkRow.index + 1; audio.setDefaultSink(sinkRow.modelData.name) }
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
              Text {
                text: "INPUT"
                color: root.screen === "audio" && root.audioFocusIndex === audio.sinks.length + 1 ? "#f9e2af" : "#a6adc8"
                font.pixelSize: 9
              }
              Item { Layout.fillWidth: true }
              Text { text: Math.round(audio.inputVolumePct) + "%"; color: "#a6adc8"; font.pixelSize: 9 }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#313244"
              border.width: root.screen === "audio" && root.audioFocusIndex === audio.sinks.length + 1 ? 1 : 0
              border.color: "#f9e2af"

              Rectangle {
                width: parent.width * (audio.inputVolumePct / 100)
                height: parent.height
                radius: 3
                color: audio.inputMuted ? "#585b70" : "#89b4fa"
                Behavior on width { NumberAnimation { duration: 120 } }
              }

              MouseArea {
                anchors.fill: parent
                onPositionChanged: if (pressed) audio.setInputVolume(mouseX / width * 100)
                onClicked: audio.setInputVolume(mouseX / width * 100)
              }
            }

            Repeater {
              model: audio.sources

              Rectangle {
                id: sourceRow
                required property int index
                required property var modelData
                Layout.fillWidth: true
                height: 32
                radius: 6
                color: modelData.active ? "#45475a" : "#313244"
                border.width: root.screen === "audio" && root.audioFocusIndex === audio.sinks.length + 2 + index ? 2 : 0
                border.color: "#f9e2af"

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 8
                  spacing: 8
                  Text {
                    text: ""
                    font.family: "Symbols Nerd Font"
                    color: sourceRow.modelData.active ? "#89b4fa" : "#a6adc8"
                    font.pixelSize: 12
                  }
                  Text { text: sourceRow.modelData.label; color: "#cdd6f4"; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                  Text {
                    visible: sourceRow.modelData.active
                    text: ""
                    font.family: "Symbols Nerd Font"
                    color: "#89b4fa"
                    font.pixelSize: 10
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: { root.audioFocusIndex = audio.sinks.length + 2 + sourceRow.index; audio.setDefaultSource(sourceRow.modelData.name) }
                }
              }
            }
          }
}
