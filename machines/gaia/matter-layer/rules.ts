import { defineRules } from "matter-layer/rules";

import guestBedroomDevices from "./rooms/guest-bedroom.devices";
import mbrBathroomDevices from "./rooms/mbr-bathroom.devices";
import mbrDevices from "./rooms/mbr.devices";
import networkClosetDevices from "./rooms/network-closet.devices";
import nurseryDevices from "./rooms/nursery.devices";
import officeDevices from "./rooms/office.devices";
import pantryDevices from "./rooms/pantry.devices";
import upstairsBathroomDevices from "./rooms/upstairs-bathroom.devices";

import guestBedroomRules from "./rooms/guest-bedroom.rules";
import mbrBathroomRules from "./rooms/mbr-bathroom.rules";
import mbrRules from "./rooms/mbr.rules";
import networkClosetRules from "./rooms/network-closet.rules";
import nurseryRules from "./rooms/nursery.rules";
import officeRules from "./rooms/office.rules";
import pantryRules from "./rooms/pantry.rules";
import upstairsBathroomRules from "./rooms/upstairs-bathroom.rules";

export default defineRules({
  devices: [
    officeDevices,
    mbrBathroomDevices,
    mbrDevices,
    nurseryDevices,
    pantryDevices,
    upstairsBathroomDevices,
    networkClosetDevices,
    guestBedroomDevices,
  ],
  rules: [
    officeRules,
    mbrBathroomRules,
    mbrRules,
    nurseryRules,
    pantryRules,
    upstairsBathroomRules,
    networkClosetRules,
    guestBedroomRules,
  ],
});
