import { any, defineRoomDevices, pulse, signal } from "matter-layer/rules";
import { fp300, innovelli, ms605Presence, myggbett } from "matter-layer/presets";

export default defineRoomDevices("mbrBathroom", ({ room }) => {
  room.main = innovelli("mbrBathroom.main");
  room.mirror = innovelli("mbrBathroom.mirror");
  room.warm = innovelli("mbrBathroom.warm", {
    on: { level: "40%" },
  });
  room.toiletLight = innovelli("mbrBathroom.toiletLight");
  room.toiletFan = innovelli("mbrBathroom.toiletFan");
  room.showerLight = innovelli("mbrBathroom.shower");
  room.mainPresence = fp300("mbrBathroom.mainPresence");
  room.toilet = ms605Presence("mbrBathroom.toiletPresence");
  room.shower = ms605Presence("mbrBathroom.showerPresence");
  room.door = myggbett("mbrBathroom.door");

  room.toiletPresence = signal(() => room.toilet.presence);
  room.showerPresence = signal(() => room.shower.presence);
  room.presence = signal(() =>
    any(
      room.mainPresence.presence,
      room.toiletPresence,
      room.showerPresence,
      pulse(room.door.open, { activeWhen: true, for: "15s" }),
    ),
  );
});
