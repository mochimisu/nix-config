import { defineRoomRules } from "matter-layer/rules";
import { bindBilresaBlinds } from "matter-layer/presets";

export default defineRoomRules("office", ({ room, rule, scene }) => {
  bindBilresaBlinds(room.blindsRemote, room.blinds);

  const lights = [room.main, room.floorLamp, room.deskLight1, room.deskLight2];
  const normalLights = rule("normal-lights", () => {
    room.main.auto(room.presence && room.dark);
    room.floorLamp.auto(room.presence);
    room.deskLight1.auto(room.presence);
    room.deskLight2.auto(room.presence);
  });
  const lightsOff = rule("lights-off", () => {
    for (const light of lights) {
      light.auto(false);
    }
  });
  const blindsClosed = rule("blinds-closed", () => {
    room.blinds.close();
  });
  const brightLights = rule("bright-lights", () => {
    for (const light of lights) {
      light.set({ power: "on", level: "100%" });
    }
  });

  const defaultScene = scene("Default", [normalLights]);
  const darkScene = scene("Dark", [defaultScene, lightsOff]);
  scene("Blackout", [darkScene, blindsClosed]);
  scene("Bright", [defaultScene, brightLights]);
});
