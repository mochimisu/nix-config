import { any, defineRoomDevices, pulse, signal } from "matter-layer/rules";
import {
  bilresa,
  ms605Presence,
  myggbett,
  nanoleafLight,
  smartwings,
  smartwingsGroup,
} from "matter-layer/presets";

export default defineRoomDevices("mbr", ({ room }) => {
  room.bedLight = nanoleafLight("mbr.bedLight", {
    on: { level: "15%" },
  });
  room.blindsRemote = bilresa("mbr.blindsRemote");
  room.blindsRemote2 = bilresa("mbr.blindsRemote2");
  room.doorBlinds = smartwingsGroup([
    "mbr.doorBlindsLeft",
    "mbr.doorBlindsRight",
  ]);
  room.windowBlinds = smartwings("mbr.windowBlinds", {
    openPosition: "70%",
  });
  room.blinds = smartwingsGroup([...room.doorBlinds.covers, room.windowBlinds]);
  room.door = myggbett("mbr.door");
  room.occupancy = ms605Presence("mbr.presence2");

  room.presence = signal(() =>
    any(
      room.occupancy.presence,
      pulse(room.door.open, { activeWhen: true, for: "15s" }),
    ),
  );
});
