{...}: {
  sops = {
    # Generate once on host:
    #   sudo install -d -m 0700 /var/lib/sops-nix
    #   sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
    #   sudo chmod 0600 /var/lib/sops-nix/key.txt
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets."matter-env" = {
      sopsFile = ./secrets/matter-env.env;
      format = "dotenv";
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };
}
