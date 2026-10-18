// Manual live benchmark: visible phone, empty input region, no focus or app actions.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../home/apps/quickshell/phone-launcher"
ShellRoot {
 PanelWindow {
  id: win
  screen: Quickshell.screens.find(s => s.name === Quickshell.env("PROBE_OUTPUT"))
  anchors { top:true; right:true }
  anchors { bottom:true; left:true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "sekai-frame-probe"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  color:"transparent"
  property var intervals: []
  Presentation {
   anchors.fill:parent
   autoOpen:false
   services: QtObject {property string hostname:"FRAME TEST";property string wallpaper:Quickshell.env("PROBE_WALLPAPER") || "";property bool wallpaperVideo:wallpaper.length > 0;property bool active:true;property date now:new Date();property string networkLabel:"Connected";property string bluetoothLabel:"On";property string audioLabel:"50%";property string download:"—";property string upload:"—";property bool muted:false;property real volume:.5;property bool audioReady:false}
   SequentialAnimation on travel {loops:Animation.Infinite; NumberAnimation {from:1;to:0;duration:260;easing.type:Easing.OutCubic} PauseAnimation {duration:100} NumberAnimation {from:0;to:1;duration:180;easing.type:Easing.InCubic} }
  }
  FrameAnimation { running:true; onTriggered: { if(elapsedTime > 1) win.intervals.push(frameTime*1000); } }
  Timer {interval:6000;running:true;onTriggered:{
   let v=win.intervals.slice().sort((a,b)=>a-b); console.log("FRAME_PROBE", win.screen.name,  "samples",v.length,"meanMs",v.reduce((a,b)=>a+b,0)/v.length,"p50Ms",v[Math.floor(v.length*.5)],"p95Ms",v[Math.floor(v.length*.95)]);Qt.quit();
  }}
 }
}
