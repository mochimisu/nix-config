{

  nixpkgs.config = {
    allowUnfree = true;
  };
  services.nix-daemon.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  programs.zsh.enable = true;
  system.stateVersion = 5;

  users.users.brandonw = {
    home = "/Users/brandonw";
  };
}
