import { defineRoomRules } from "matter-layer/rules";

export default defineRoomRules("pantry", ({ room, rule }) => {
  rule("light", () => room.light.auto(room.presence));
});
