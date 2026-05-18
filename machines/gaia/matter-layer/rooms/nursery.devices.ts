import { defineRoomDevices } from "matter-layer/rules";
import { bilresa, smartwingsGroup } from "matter-layer/presets";

export default defineRoomDevices("nursery", ({ room }) => {
  room.blindsRemote = bilresa("nursery.blindsRemote");
  room.blinds = smartwingsGroup(["nursery.blinds"]);
});
