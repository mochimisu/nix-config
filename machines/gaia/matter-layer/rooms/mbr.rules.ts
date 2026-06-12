import { defineRoomRules, time } from "matter-layer/rules";
import { bilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("mbr", ({ room, rule }) => {
  bilresaBlinds(room.blindsRemote, room.blinds);
  bilresaBlinds(room.blindsRemote2, room.blinds);

  rule("bed-light", () => {
    const activeWindow = time.minuteBetween("8:00", "20:00");
    room.bedLight.auto(room.presence && activeWindow);
  });
  rule("blinds", () => {
    if (time.minuteBetween("8:00", "20:00")) {
      room.blinds.open();
    } else {
      room.blinds.close();
    }
  });
});
