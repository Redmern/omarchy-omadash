import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root

          anchors.fill: parent
          anchors.margins: 16
          spacing: 10
          opacity: root.screen === "settings" ? 1 : 0
          enabled: root.screen === "settings"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: "#89b4fa" }
            Text { text: "Settings"; color: "#f4f4f8"; font.pixelSize: 15; font.bold: true; Layout.fillWidth: true }
          }

          Text { text: "KEYBINDS"; color: "#a6adc8"; font.pixelSize: 9 }

          ListView {
            id: settingsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.settingsActions()
            currentIndex: root.settingsIndex
            highlightMoveDuration: 100

            delegate: Rectangle {
              id: bindRow
              required property int index
              required property string modelData
              width: settingsList.width
              height: 32
              radius: 6
              color: root.settingsIndex === index ? "#45475a" : "transparent"
              border.width: root.rebindingAction === bindRow.modelData ? 2 : 0
              border.color: "#f9e2af"

              RowLayout {
                anchors.fill: parent
                anchors.margins: 8

                Text {
                  text: root.settingsLabel(bindRow.modelData)
                  color: "#cdd6f4"
                  font.pixelSize: 12
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }

                Rectangle {
                  width: bindRow.modelData === "holdtime" ? 84 : 60
                  height: 22
                  radius: 5
                  color: root.rebindingAction === bindRow.modelData ? "#89b4fa" : "#313244"

                  Text {
                    anchors.centerIn: parent
                    text: {
                      if (root.rebindingAction === bindRow.modelData) return "…"
                      var k = root.settingsKeyFor(bindRow.modelData)
                      if (bindRow.modelData === "holdtime") return "◄ " + k + " ►"
                      return k === " " ? "SPACE" : k.toUpperCase()
                    }
                    color: root.rebindingAction === bindRow.modelData ? "#1e1e2e" : "#cdd6f4"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.settingsIndex = bindRow.index
                  if (bindRow.modelData === "showhints") root.toggleShowKeybindHints()
                  else if (bindRow.modelData !== "holdtime") root.startRebind(bindRow.modelData)
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 26
            radius: 6
            color: "#313244"

            Text {
              anchors.centerIn: parent
              text: "Reset to defaults"
              color: "#cdd6f4"
              font.pixelSize: 11
            }

            MouseArea { anchors.fill: parent; onClicked: root.resetKeybinds() }
          }
}
