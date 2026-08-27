import { defineRoomRules } from "matter-layer/rules";
import { bindBilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("guestBedroom", ({ room }) => {
  bindBilresaBlinds(room.blindsRemote, room.blinds);
});
