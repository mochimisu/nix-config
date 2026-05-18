import { defineRoomRules, state } from "matter-layer/rules";

export default defineRoomRules("mbrBathroom", ({ room, rule }) => {
  rule("lights", () => {
    const daytime = state.timeBetween("6:00", "22:00");
    const morning = daytime && state.timeBetween("6:00", "11:00");
    room.main.auto(room.presence && daytime);
    room.mirror.auto(room.presence && morning);
    room.warm.auto(room.presence && !daytime);
  });

  rule("toilet", () => {
    room.toiletLight.auto(room.toiletPresence);
  });

  rule("toilet-fan", () => {
    const wasOccupiedLongEnough = state.wasTrueFor(room.toiletPresence, "2m");
    if (room.toiletPresence) {
      state.cancelDelay("mbr-bathroom.toiletFan.offDelay");
      room.toiletFan.auto(true);
      return;
    }

    if (wasOccupiedLongEnough) {
      room.toiletFan.auto(
        state.delayClear("mbr-bathroom.toiletFan.offDelay", "5m", {
          power: "off",
        }) ?? true,
      );
      return;
    }

    room.toiletFan.auto(false);
  });

  rule("shower-light", () => room.showerLight.auto(room.showerPresence));
});
