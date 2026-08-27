import { defineRoomRules, time } from "matter-layer/rules";
import { bindBilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("mbr", ({ room, rule, scene }) => {
  bindBilresaBlinds(room.blindsRemote, room.blinds);
  bindBilresaBlinds(room.blindsRemote2, room.blinds);

  const presenceBedLight = rule("presence-bed-light", () => {
    room.bedLight.auto(room.presence);
  });
  const scheduledBlinds = rule("scheduled-blinds", () => {
    if (time.minuteBetween("8:00", "17:00")) {
      room.blinds.open();
    } else {
      room.blinds.close();
    }
  });
  const blackoutBlinds = rule("blackout-blinds", () => {
    room.blinds.close();
  });

  rule("blinds-status", () => {
    room.blindsStatus.auto(room.blindsOverrideActive
      ? { power: "on", color: "purple", level: "50%" }
      : false);
  });

  const defaultScene = scene("Default", [presenceBedLight, scheduledBlinds]);
  scene("Blackout", [defaultScene, blackoutBlinds]);
});
