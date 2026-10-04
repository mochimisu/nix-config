{ config, lib, inputs, ... }:
let
  cfg = config.services.wikimemClient;
  host = config.networking.hostName;
  encrypted = ./secrets + "/wikimem-${host}.enc";

in {
  imports = [ inputs.sops-nix.nixosModules.sops ];
  options.services.wikimemClient = {
    enable = lib.mkEnableOption "declarative Wikimem client credentials and routing" // { default = host != "oai-dev"; };
    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = if builtins.pathExists encrypted then encrypted else null;
      description = "Per-host SOPS-encrypted API key. Missing enrollment uses the private runtime key path.";
    };
    keyFile = lib.mkOption {
      type = lib.types.str;
      default = if cfg.sopsFile != null then "/run/secrets/wikimem" else "/home/brandon/.config/wikimem/codex.key";
    };
  };
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.ssh.knownHosts.wikimem-gaia-lan = {
        hostNames = [ "gaia" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBwbEIcM4xLTzLVcAzy2LDWh/j4u0G7WixFJqwlH2dyb";
      };
      # Upkeep belongs to the service deployment; never restart the legacy local runner.
      systemd.services.wikiskill-daily-daemon.enable = lib.mkForce false;
    }
    (lib.mkIf (cfg.sopsFile != null) {
      sops.secrets.wikimem = {
        sopsFile = cfg.sopsFile;
        format = "binary";
        key = "";
        owner = "brandon";
        group = "users";
        mode = "0400";
      };
    })
  ]);
}
