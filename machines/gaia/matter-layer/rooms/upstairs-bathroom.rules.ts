import { defineRoomRules } from "matter-layer/rules";

export default defineRoomRules("upstairsBathroom", ({ room, rule }) => {
  rule("light", () => room.light.auto(room.presence));
});
