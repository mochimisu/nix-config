import { defineRoomDevices } from "matter-layer/rules";
import { matterDevice } from "matter-layer/devices";

/** Visible cars by area. Unknown identity is distinct from unavailable video. */
function carsInArea(area: string, displayName: string) {
  const path = `sensor.cars_in_${area}`;
  const metrics = [{ property: "cars", label: "Cars", provider: "ha" as const, path }];
  if (area === "driveway") {
    metrics.push({ property: "vehicleCount", label: "Vehicles detected", provider: "ha", path: "sensor.driveway_vehicle_count" });
    metrics.push({ property: "unknownCount", label: "Unidentified vehicles", provider: "ha", path: "sensor.driveway_unknown_vehicle_count" });
  }
  const device = matterDevice(`cars.${area}`, {
    provider: "ha",
    vendor: "Car Presence",
    product: "Camera Presence",
    displayName,
    metrics,
  });
  device.addSource<string | undefined>("cars", { provider: "ha", path });
  if (area === "driveway") {
    device.addSource<number | undefined>("vehicleCount", { provider: "ha", path: "sensor.driveway_vehicle_count", encoding: "ha-number" });
    device.addSource<number | undefined>("unknownCount", { provider: "ha", path: "sensor.driveway_unknown_vehicle_count", encoding: "ha-number" });
  }
  return device;
}

export default defineRoomDevices("cars", ({ room }) => {
  room.garage = carsInArea("garage", "Cars in garage");
  room.driveway = carsInArea("driveway", "Cars in driveway");
});
