import { defineRoomRules } from "matter-layer/rules";
import { bilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("office", ({ room, rule }) => {
  bilresaBlinds(room.blindsRemote, room.blinds);

  rule("lights", () => {
    room.main.auto(room.presence && room.dark);
    room.floorLamp.auto(room.presence);
  });
});
