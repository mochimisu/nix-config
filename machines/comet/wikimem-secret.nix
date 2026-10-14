# Dedicated Comet credential issued/encrypted on Gaia; contains no plaintext.
{ config, inputs, lib, ... }:
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];
  sops.age = {
    keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    generateKey = false;
    sshKeyPaths = [];
  };
  sops.secrets.wikimem = {
    sopsFile = ../../secrets/wikimem-comet.enc;
    format = "binary";
    key = "";
    mode = "0400";
  };
  programs.wikimem.keyFile = lib.mkForce config.sops.secrets.wikimem.path;
  # Existing client enable policy and account-level OAuth connection are unchanged.
}
