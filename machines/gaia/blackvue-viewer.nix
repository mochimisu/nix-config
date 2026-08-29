{inputs, ...}: {
  imports = [inputs.dashcam-viewer.nixosModules.default];

  services.dashcam-viewer = {
    enable = true;
    videoRoot = "/earth/blackvue";
    port = 3000;
    openFirewall = true;

    # Keep access aligned with the archive ingest jobs. In particular, Brandon
    # is also in `media`, which owns the TeslaUSB archive.
    user = "brandon";
    group = "users";
    createUser = false;
    archiveWritable = true;

    after = ["earth.mount"];
    requires = ["earth.mount"];
  };
}
