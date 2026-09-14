import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root

          anchors.fill: parent
          anchors.margins: 10
          spacing: 8
          opacity: root.screen === "grid" ? 1 : 0
          enabled: root.screen === "grid"

          Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true

            Item { Layout.fillWidth: true }

            PaneHint { root: view.root; screenName: "grid" }

            Rectangle {
              width: 26
              height: 26
              radius: 13
              color: settingsGearArea.containsMouse ? "#313244" : "transparent"

              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                anchors.centerIn: parent
                text: ""
                font.family: "Symbols Nerd Font"
                font.pixelSize: 13
                color: "#6c7086"
              }

              MouseArea {
                id: settingsGearArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  root.screen = "settings"
                  root.settingsIndex = 0
                  root.rebindingAction = ""
                }
              }
            }
          }

          GridLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            columns: root.gridColumns
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
              model: root.tiles

              Rectangle {
                id: tile
                required property int index
                required property var modelData

                width: 84
                height: 64
                radius: 8
                color: root.selectedIndex === index ? "#45475a" : "#313244"
                border.width: root.selectedIndex === index ? 2 : 0
                border.color: "#89b4fa"

                Behavior on color {
                  ColorAnimation { duration: 120 }
                }

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: 4

                  Text {
                    text: tile.modelData.icon
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 20
                    color: "#cdd6f4"
                    Layout.alignment: Qt.AlignHCenter
                  }

                  Text {
                    text: tile.modelData.label
                    color: "#cdd6f4"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                  }
                }

                Text {
                  visible: root.isHintVisible("grid")
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.margins: 4
                  text: (root.tileKeys[tile.modelData.view] || "").toUpperCase()
                  color: "#6c7086"
                  font.pixelSize: 9
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    root.selectedIndex = tile.index
                    root.activateSelection()
                  }
                }
              }
            }
          }
}
