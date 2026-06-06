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
    const occupiedLongEnough = state.wasTrueFor(room.toiletPresence, "2m");
    room.toiletFan.auto(state.holdTrue("mbr-bathroom.toiletFan.offDelay", occupiedLongEnough, "5m"));
  });

  rule("dehumidifier", () => {
    const humidity = Number(room.environment.humidity ?? 0);
    const activeWindow = state.timeBetween("6:00", "23:30");
    const humidityLowLongEnough = state.wasTrueFor(humidity < 45, "10m");
    const active = state.latch(
      "mbr-bathroom.dehumidifier.humidity",
      activeWindow && humidity > 65,
      !activeWindow || humidityLowLongEnough,
    );
    room.dehumidifier.auto(active);
    room.toiletFan.auto(active);
    room.fan.auto(active);
  });

  rule("shower-light", () => room.showerLight.auto(room.showerPresence));
});
