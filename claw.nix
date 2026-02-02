{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodePackages.npm
    google-cloud-sdk
    tailscale
  ];
}
