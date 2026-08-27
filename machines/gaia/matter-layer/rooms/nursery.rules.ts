import { defineRoomRules } from "matter-layer/rules";
import { bindBilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("nursery", ({ room }) => {
  bindBilresaBlinds(room.blindsRemote, room.blinds);
});
