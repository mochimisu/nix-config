{...}: let
  matterEnvFile = ./secrets/matter-env.env;
in {
  assertions = [
    {
      assertion = builtins.readFile matterEnvFile != "";
      message = "machines/gaia/secrets/matter-env.env is empty; Matter client services need /run/secrets/matter-env.";
    }
  ];

  sops = {
    # Generate once on host:
    #   sudo install -d -m 0700 /var/lib/sops-nix
    #   sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
    #   sudo chmod 0600 /var/lib/sops-nix/key.txt
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets."matter-env" = {
      sopsFile = matterEnvFile;
      format = "dotenv";
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };
}
