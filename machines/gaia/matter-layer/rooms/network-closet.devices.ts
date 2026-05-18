import { defineRoomDevices } from "matter-layer/rules";
import { kajplats, myggbett } from "matter-layer/presets";

export default defineRoomDevices("networkCloset", ({ room }) => {
  room.light = kajplats("networkCloset.light");
  room.door = myggbett("networkCloset.door");
});
