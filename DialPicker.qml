// Omatrix — a semicircular "Omnitrix" dial picker for live Wallpaper Engine
// wallpapers. An Omarchy `overlay` plugin: summon it, spin the dial with
// scroll / arrows / drag, Enter applies via `omarchy-we set`. The last card
// stops the live wallpaper.
//
// Own code (not derived from any other shell's picker). Data comes from
// `omarchy-we ipc entries` (JSON: id/title/type/preview/current).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  // Injected by omarchy-shell when the overlay is summoned.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property var items: []
  readonly property int count: items.length

  // The dial: `target` is the integer index we're spinning to; `pos` follows it
  // with easing. pos is left unbounded and each card takes the shortest wrapped
  // path (see wrapDelta), so the ring loops without a seam.
  property real target: 0
  property real pos: target
  Behavior on pos { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

  readonly property real stepDeg: 18          // angular gap between cards
  readonly property color accent: "#38e08b"   // Omnitrix green
  readonly property color frame: "#181b22"
  readonly property color line: "#242833"

  // Arc geometry, from the PanelWindow size (root Item itself is 0x0 — only the
  // child PanelWindow spans the screen).
  property real cx: panel.width / 2
  property real radius: Math.min(panel.width * 0.27, 430)
  property real cy: panel.height * 0.90 + radius * 0.46
  readonly property real cardW: Math.min(panel.width * 0.11, 168)

  function open(payloadJson) {
    root.opened = true
    loader.running = true
    Qt.callLater(function () { keys.forceActiveFocus() })
  }
  function close() { root.opened = false }
  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.dkgamer02ai.wallpaper-engine")
  }
  function toggle() { if (root.opened) dismiss(); else open("{}") }

  function spin(n) { root.target += n }
  function selectedIndex() {
    return root.count ? (((Math.round(root.pos) % root.count) + root.count) % root.count) : 0
  }
  function selectedItem() { return root.count ? root.items[selectedIndex()] : null }

  // Shortest signed distance from card `i` to the current position, wrapped
  // into (-count/2, count/2] so the nearest cards always sit at the apex.
  function wrapDelta(i) {
    if (!root.count) return 0
    var d = (((i - root.pos) % root.count) + root.count) % root.count
    if (d > root.count / 2) d -= root.count
    return d
  }

  function apply() {
    var it = selectedItem()
    if (!it) return
    if (String(it.id) === "__STOP__") Quickshell.execDetached(["omarchy-we", "stop"])
    else Quickshell.execDetached(["omarchy-we", "set", String(it.id)])
    root.dismiss()
  }

  // Load the catalog and append a Stop card as the last item on the ring.
  Process {
    id: loader
    command: ["omarchy-we", "ipc", "entries"]
    stdout: StdioCollector {
      onStreamFinished: {
        var arr = []
        try { arr = JSON.parse(text) } catch (e) { arr = [] }
        arr.push({ id: "__STOP__", title: "Stop Live Wallpaper", type: "stop", preview: "" })
        root.items = arr
        root.target = 0
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omatrix"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // scrim
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: "#e60a0b0f" }
        GradientStop { position: 1.0; color: "#f206070a" }
      }
    }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    // ---- focused preview (top) ------------------------------------------
    Item {
      id: preview
      width: Math.min(parent.width * 0.46, 620)
      height: width * 9 / 16
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: parent.height * 0.13
      opacity: root.selectedItem() && root.selectedItem().type === "stop" ? 0.55 : 1

      Rectangle {
        anchors.fill: parent; radius: 16; clip: true
        color: root.frame; border.width: 1; border.color: root.line
        AnimatedImage {
          anchors.fill: parent
          source: {
            var it = root.selectedItem()
            return (it && it.preview) ? "file://" + it.preview : ""
          }
          fillMode: Image.PreserveAspectCrop
          playing: true
          cache: false
          // AnimatedImage obeys the gif's embedded loop count, so a finite gif
          // freezes after one pass. Restart on selection change, and wrap the
          // last frame back to the first for a continuous loop.
          onSourceChanged: { currentFrame = 0; playing = true }
          onCurrentFrameChanged: if (frameCount > 1 && currentFrame >= frameCount - 1) currentFrame = 0
        }
        // title + type chip
        Rectangle {
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: 56
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#00060709" }
            GradientStop { position: 1.0; color: "#d1060709" }
          }
        }
        Text {
          anchors { left: parent.left; bottom: parent.bottom; margins: 16 }
          width: parent.width - 150
          text: { var it = root.selectedItem(); return it ? it.title : "" }
          color: "#eceef2"; font.pixelSize: 20; font.weight: Font.DemiBold
          elide: Text.ElideRight
        }
        Rectangle {
          anchors { right: parent.right; bottom: parent.bottom; margins: 14 }
          radius: 999; height: 22; width: chip.width + 18
          color: "#990a0c10"; border.width: 1
          border.color: { var it = root.selectedItem(); return (it && it.type === "scene") ? root.accent : (it && it.type === "video") ? "#274257" : "#5a2a2a" }
          Text {
            id: chip; anchors.centerIn: parent
            text: { var it = root.selectedItem(); return it ? String(it.type).toUpperCase() : "" }
            font.pixelSize: 11; font.letterSpacing: 1.5
            font.family: "monospace"
            color: { var it = root.selectedItem(); return (it && it.type === "scene") ? root.accent : (it && it.type === "video") ? "#8fd0ff" : "#ff8f8f" }
          }
        }
      }
    }

    // ---- the dial (cards on an arc) -------------------------------------
    Item {
      anchors.fill: parent
      Repeater {
        model: root.items
        delegate: Rectangle {
          id: card
          required property var modelData
          required property int index
          readonly property real rel: root.wrapDelta(index)
          readonly property real ang: (90 - rel * root.stepDeg) * Math.PI / 180
          readonly property bool isSel: root.selectedIndex() === index

          width: root.cardW; height: root.cardW * 0.625
          radius: 12; clip: true
          color: root.frame
          border.width: isSel ? 2 : 1
          border.color: isSel ? root.accent : root.line
          antialiasing: true

          x: root.cx + root.radius * Math.cos(ang) - width / 2
          y: root.cy - root.radius * Math.sin(ang) - height / 2
          transformOrigin: Item.Center
          rotation: -(90 - rel * root.stepDeg) * 0.5
          scale: Math.max(0.55, 1.18 - Math.abs(rel) * 0.16)
          z: Math.round(200 - Math.abs(rel) * 10)
          opacity: Math.abs(rel) > 4.2 ? 0 : 1
          visible: opacity > 0

          // green glow ring on the focused card
          Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8; height: parent.height + 8; radius: 15
            color: "transparent"; border.width: 2; border.color: root.accent
            opacity: card.isSel ? 0.9 : 0; z: -1
          }

          Image {
            anchors.fill: parent
            visible: card.modelData.type !== "stop"
            source: card.modelData.preview ? "file://" + card.modelData.preview : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; cache: true; sourceSize.width: 320
          }
          // stop face
          Rectangle {
            anchors.fill: parent
            visible: card.modelData.type === "stop"
            gradient: Gradient {
              GradientStop { position: 0.0; color: "#241416" }
              GradientStop { position: 1.0; color: "#0d0708" }
            }
            Rectangle {
              anchors.centerIn: parent; width: parent.width * 0.22; height: width
              radius: 6; color: "#ff6b6b"
            }
          }
          // label
          Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 22
            gradient: Gradient {
              GradientStop { position: 0.0; color: "#00060709" }
              GradientStop { position: 1.0; color: "#d9060709" }
            }
            Text {
              anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 }
              text: card.modelData.title
              color: "#dfe3ea"; font.pixelSize: 11; elide: Text.ElideRight
            }
          }
          MouseArea { anchors.fill: parent; onClicked: root.spin(root.wrapDelta(index)) }
        }
      }
    }

    // Omnitrix hub under the arc
    Rectangle {
      width: 170; height: 170; radius: 85
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height - 52
      color: "#0a0f0c"; border.width: 2; border.color: "#1d7d4e"
      Rectangle {
        anchors.centerIn: parent; width: 118; height: 118; radius: 59
        color: "transparent"; border.width: 2; border.color: "#5938e08b"
      }
    }

    // wordmark — top center
    Text {
      anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: parent.height * 0.03 }
      text: "OMATRIX"; color: "#eceef2"; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 8; font.family: "monospace"
    }

    // HUD hint
    Text {
      anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
      text: "◄ ►  or scroll to spin    ·    Enter apply    ·    Esc close"
      color: "#7f8593"; font.pixelSize: 13; font.letterSpacing: 1.2; font.family: "monospace"
    }

    // ---- input ----------------------------------------------------------
    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function (ev) { root.spin((ev.angleDelta.y + ev.angleDelta.x) < 0 ? 1 : -1) }
    }
    // drag to spin
    property real dragX: NaN
    property real dragBase: 0
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      propagateComposedEvents: true
      onPressed: function (m) { panel.dragX = m.x; panel.dragBase = root.target; m.accepted = false }
      onPositionChanged: function (m) {
        if (!isNaN(panel.dragX)) root.target = panel.dragBase - (m.x - panel.dragX) / 60
      }
      onReleased: function (m) {
        if (!isNaN(panel.dragX)) { panel.dragX = NaN; root.target = Math.round(root.target) }
      }
    }

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: function (e) {
        if (e.key === Qt.Key_Escape) { root.dismiss(); e.accepted = true }
        else if (e.key === Qt.Key_Left) { root.spin(-1); e.accepted = true }
        else if (e.key === Qt.Key_Right) { root.spin(1); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.apply(); e.accepted = true }
      }
    }
  }
}
