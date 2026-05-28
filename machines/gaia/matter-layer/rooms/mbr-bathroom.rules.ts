import { defineRoomRules, state } from "matter-layer/rules";

export default defineRoomRules("mbrBathroom", ({ room, rule }) => {
  rule("lights", () => {
    room.main.auto(room.presence && room.daytime);
    room.mirror.auto(room.presence && room.morning);
    room.warm.auto(room.presence && !room.daytime);
  });

  rule("toilet", () => {
    const onState = room.daytime ? true : { power: "on", level: "15%" };
    room.toiletLight.auto(room.toiletPresence ? onState : false);
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
