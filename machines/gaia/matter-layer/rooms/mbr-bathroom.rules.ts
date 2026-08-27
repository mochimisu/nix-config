import { defineRoomRules, state } from "matter-layer/rules";

export default defineRoomRules("mbrBathroom", ({ room, rule, scene }) => {
  const normalLights = rule("normal-lights", () => {
    room.main.auto(room.presence && room.daytime);
    room.mirror.auto(room.presence && room.morning);
    room.warm.auto(room.presence && !room.daytime);
  });

  const toiletLight = rule("toilet-light", () => {
    const onState = room.daytime ? true : { power: "on", level: "15%" };
    room.toiletLight.auto(room.toiletPresence ? onState : false);
  });

  const delayedToiletFan = rule("delayed-toilet-fan", () => {
    const occupiedLongEnough = state.wasTrueFor(room.toiletPresence, "2m");
    room.toiletFan.auto(state.holdTrue("mbr-bathroom.toiletFan.offDelay", occupiedLongEnough, "5m"));
  });

  const humidityControl = rule("humidity-control", () => {
    const humidity = Number(room.humidity ?? 0);
    const activeWindow = state.timeBetween("6:00", "23:30");
    const humidityLowLongEnough = state.wasTrueFor(humidity < 50, "10m");
    const active = state.latch(
      "mbr-bathroom.dehumidifier.humidity",
      activeWindow && humidity > 70,
      !activeWindow || humidityLowLongEnough,
    );
    room.dehumidifier.auto(active);
    room.toiletFan.auto(active);
    room.fan.auto(active);
  });

  const presenceShowerLight = rule("presence-shower-light", () => room.showerLight.auto(room.showerPresence));
  const forcedVentilation = rule("forced-ventilation", () => {
    room.toiletFan.auto(true);
    room.fan.auto(true);
  });
  const forcedDehumidification = rule("forced-dehumidification", () => {
    room.toiletFan.auto(true);
    room.fan.auto(true);
    room.dehumidifier.auto(true);
  });
  const allLightsBright = rule("all-lights-bright", () => {
    for (const light of [room.main, room.mirror, room.warm, room.toiletLight, room.showerLight]) {
      light.auto(true);
    }
  });

  const defaultScene = scene("Default", [
    normalLights,
    toiletLight,
    delayedToiletFan,
    humidityControl,
    presenceShowerLight,
  ]);
  scene("Ventilate", [defaultScene, forcedVentilation]);
  scene("Dehumidify", [defaultScene, forcedDehumidification]);
  scene("Bright", [defaultScene, allLightsBright]);
});
