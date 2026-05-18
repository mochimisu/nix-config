import { defineRoomRules } from "matter-layer/rules";

export default defineRoomRules("networkCloset", ({ room, rule }) => {
  rule("light", () => room.light.auto(room.door.open));
});
