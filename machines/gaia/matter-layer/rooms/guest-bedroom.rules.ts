import { defineRoomRules } from "matter-layer/rules";
import { bilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("guestBedroom", ({ room }) => {
  bilresaBlinds(room.blindsRemote, room.blinds);
});
