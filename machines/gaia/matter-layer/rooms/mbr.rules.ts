import { defineRoomRules } from "matter-layer/rules";
import { bilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("mbr", ({ room, rule }) => {
  bilresaBlinds(room.blindsRemote, room.blinds);
  bilresaBlinds(room.blindsRemote2, room.blinds);

  rule("bed-light", () => room.bedLight.auto(room.presence));
});
