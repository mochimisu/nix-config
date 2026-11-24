# Gaia owns the cache server; common.nix configures cache clients.
{pkgs, ...}: {
  services.nix-serve = {
    enable = true;
    # The Perl cache server imports Nix::Store. Nix 2.35 dropped those bindings.
    package = pkgs.nix-serve.override {nix = pkgs.nixVersions.nix_2_34;};
    port = 5000;
    openFirewall = true;
    secretKeyFile = "/home/brandon/.local/state/nix-cache/gaia-cache-priv-key.pem";
  };
}
