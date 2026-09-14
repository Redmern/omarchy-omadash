import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: view
  property var root

  anchors.fill: parent
  anchors.margins: 16
  spacing: 10
  opacity: root.screen === "calendar" ? 1 : 0
  enabled: root.screen === "calendar"

  Behavior on opacity {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text { text: ""; font.family: "Symbols Nerd Font"; font.pixelSize: 20; color: "#89b4fa" }
    Text {
      text: root.monthNames[root.calendarSelected.getMonth()] + " " + root.calendarSelected.getDate()
      color: "#f4f4f8"
      font.pixelSize: 18
      font.bold: true
      Layout.fillWidth: true
    }

    PaneHint { root: view.root; screenName: "calendar" }
  }

  Text {
    visible: root.hintHeld
    text: root.hintText("calendar")
    color: "#6c7086"
    font.pixelSize: 9
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Text { text: new Date().getFullYear(); color: "#a6adc8"; font.pixelSize: 11 }

    Rectangle {
      Layout.fillWidth: true
      height: 6
      radius: 3
      color: "#313244"

      Rectangle {
        width: parent.width * root.calendarYearProgress()
        height: parent.height
        radius: 3
        color: "#89b4fa"
      }
    }

    Text { text: Math.round(root.calendarYearProgress() * 100) + "%"; color: "#a6adc8"; font.pixelSize: 11 }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 0

    Text { text: "W"; color: "#6c7086"; font.pixelSize: 10; Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter }

    Repeater {
      model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
      Text {
        required property string modelData
        text: modelData
        color: "#6c7086"
        font.pixelSize: 9
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: false
    spacing: 4

    Repeater {
      model: root.calendarWeeks()

      RowLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 0

        Text {
          text: modelData.weekNum
          color: "#6c7086"
          font.pixelSize: 9
          Layout.preferredWidth: 24
          horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
          model: modelData.days

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            radius: 13
            color: modelData.isSelected ? "#45475a" : "transparent"
            border.width: modelData.isToday ? 2 : 0
            border.color: "#89b4fa"

            Text {
              anchors.centerIn: parent
              text: modelData.day
              color: modelData.isToday ? "#89b4fa" : (modelData.inMonth ? "#cdd6f4" : "#45475a")
              font.pixelSize: 11
              font.bold: modelData.isToday || modelData.isSelected
            }
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 10

    Rectangle {
      width: 24
      height: 24
      radius: 12
      color: "transparent"
      Text { anchors.centerIn: parent; text: ""; font.family: "Symbols Nerd Font"; color: "#a6adc8"; font.pixelSize: 10 }
      MouseArea { anchors.fill: parent; onClicked: root.moveCalendarMonth(-1) }
    }

    Text {
      text: root.monthNames[root.calendarMonth].toUpperCase() + " " + root.calendarYear
      color: "#a6adc8"
      font.pixelSize: 10
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
      width: 24
      height: 24
      radius: 12
      color: "transparent"
      Text { anchors.centerIn: parent; text: ""; font.family: "Symbols Nerd Font"; color: "#a6adc8"; font.pixelSize: 10 }
      MouseArea { anchors.fill: parent; onClicked: root.moveCalendarMonth(1) }
    }
  }
}
