import { any, defineRoomDevices, pulse, signal, solarDark } from "matter-layer/rules";
import {
  alpstuga,
  bilresa,
  innovelli,
  matterLight,
  ms605Presence,
  myggbett,
  smartwingsGroup,
} from "matter-layer/presets";

export default defineRoomDevices("office", ({ room }) => {
  room.main = innovelli("office.light", {
    on: { level: "15%" },
  });
  room.floorLamp = matterLight("office.floorLamp");
  room.deskLight1 = matterLight("office.deskLight1");
  room.deskLight2 = matterLight("office.deskLight2");
  room.blindsRemote = bilresa("office.blindsRemote");
  room.blinds = smartwingsGroup(["office.blinds"]);
  room.nearPresence = ms605Presence("office.presence");
  room.farPresence = ms605Presence("office.presenceFar");
  room.door = myggbett("office.door");
  room.airQuality = alpstuga("office.airQuality");

  room.presence = signal(() =>
    any(
      room.nearPresence.presence,
      room.farPresence.presence,
      pulse(room.door.open, { activeWhen: true, for: "15s" }),
    ),
  );

  room.dark = signal(() =>
    any(room.nearPresence.lux < 120, room.farPresence.lux < 120, solarDark()),
  );
});
