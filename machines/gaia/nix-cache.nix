# Gaia owns the cache server; common.nix configures cache clients.
{...}: {
  services.nix-serve = {
    enable = true;
    port = 5000;
    openFirewall = true;
    secretKeyFile = "/home/brandon/.local/state/nix-cache/gaia-cache-priv-key.pem";
  };
}
