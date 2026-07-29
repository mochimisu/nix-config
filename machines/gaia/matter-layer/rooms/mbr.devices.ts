import { any, defineRoomDevices, pulse, signal } from "matter-layer/rules";
import {
  bilresa,
  matterLight,
  ms605Presence,
  myggbett,
  myggspray,
  nanoleafLight,
  smartwings,
  smartwingsGroup,
} from "matter-layer/presets";

export default defineRoomDevices("mbr", ({ room }) => {
  room.bedLight = nanoleafLight("mbr.bedLight", {
    on: { level: 2 },
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
  room.blindsStatus = matterLight("mbr.blindsStatus", {
    vendor: "Brandon Wang",
    product: "Custom LED",
    color: {
      cluster: 768,
      endpoint: 1,
      mode: "xy",
      colors: {
        // The handmade LED's red/green output channels are swapped.
        purple: [14723, 21544],
      },
    },
  });
  const blindLayers = room.blinds.covers.map((blind) => blind.activeLayer());
  room.blindsOverrideActive = signal(() =>
    blindLayers.some((layer) => {
      const active = layer.read();
      return active?.layer === "override" || active?.layer === "webOverride";
    }),
  );
  room.door = myggbett("mbr.door");
  room.occupancy = ms605Presence("mbr.presence2");
  room.bedLeft = myggspray("mbr.bedLeft");
  room.bedRight = myggspray("mbr.bedRight");

  room.presence = signal(() =>
    any(
      room.occupancy.presence,
      room.bedLeft.presence,
      room.bedRight.presence,
      pulse(room.door.open, { activeWhen: true, for: "15s" }),
    ),
  );
});
