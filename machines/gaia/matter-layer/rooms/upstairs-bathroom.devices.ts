import { defineRoomDevices, signal } from "matter-layer/rules";
import { fp300, innovelli } from "matter-layer/presets";

export default defineRoomDevices("upstairsBathroom", ({ room }) => {
  room.light = innovelli("upstairsBathroom.light");
  room.occupancy = fp300("upstairsBathroom.presence");
  room.presence = signal(() => room.occupancy.presence);
});
