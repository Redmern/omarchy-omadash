import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root
  property var apps

          anchors.fill: parent
          anchors.margins: 16
          spacing: 10
          opacity: root.screen === "apps" ? 1 : 0
          enabled: root.screen === "apps"

          Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          RowLayout {
            Layout.fillWidth: true
            Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 18; color: "#89b4fa" }
            Text {
              text: root.appsSearching ? (root.appsQuery.length > 0 ? root.appsQuery : "Search…") : "Apps"
              color: root.appsSearching && root.appsQuery.length === 0 ? "#6c7086" : "#f4f4f8"
              font.pixelSize: 15
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              visible: !root.appsSearching
              text: "?"
              color: "#6c7086"
              font.pixelSize: 11
            }

            PaneHint { root: view.root; screenName: "apps" }
          }

          Text {
            visible: root.isHintVisible("apps") && !root.appsSearching
            text: root.hintText("apps")
            color: "#6c7086"
            font.pixelSize: 9
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          ListView {
            id: appsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredApps()
            currentIndex: root.appsSelectedIndex
            highlightMoveDuration: 100
            spacing: 2

            delegate: Rectangle {
              id: appRow
              required property int index
              required property var modelData

              width: appsList.width
              height: 34
              radius: 6
              color: root.appsSelectedIndex === index ? "#45475a" : "transparent"

              RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Image {
                  source: appRow.modelData.icon
                  Layout.preferredWidth: 20
                  Layout.preferredHeight: 20
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                }

                Text {
                  text: appRow.modelData.name
                  color: "#cdd6f4"
                  font.pixelSize: 12
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.appsSelectedIndex = appRow.index
                  root.activateApp()
                }
              }
            }
          }
}
