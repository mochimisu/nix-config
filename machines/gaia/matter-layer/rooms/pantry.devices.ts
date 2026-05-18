import { defineRoomDevices, signal } from "matter-layer/rules";
import { innovelli, ms605Presence } from "matter-layer/presets";

export default defineRoomDevices("pantry", ({ room }) => {
  room.light = innovelli("pantry.light");
  room.occupancy = ms605Presence("pantry.presence");
  room.presence = signal(() => room.occupancy.presence);
});
