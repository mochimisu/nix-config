import { defineRoomDevices } from "matter-layer/rules";
import { bilresa, smartwingsGroup } from "matter-layer/presets";

export default defineRoomDevices("guestBedroom", ({ room }) => {
  room.blindsRemote = bilresa("guestBedroom.blindsRemote");
  room.blinds = smartwingsGroup([
    "guestBedroom.windowBlinds",
    "guestBedroom.doorBlinds",
  ]);
});
