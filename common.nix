{
  pkgs,
  inputs,
  ...
}: let
  codexBase = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  codexCli = pkgs.symlinkJoin {
    name = "codex-cli-with-zlib";
    paths = [codexBase];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      if [ -f "$out/bin/codex" ]; then
        wrapProgram "$out/bin/codex" --prefix LD_LIBRARY_PATH : ${pkgs.zlib}/lib
      fi
      if [ -f "$out/bin/codex-raw" ]; then
        wrapProgram "$out/bin/codex-raw" --prefix LD_LIBRARY_PATH : ${pkgs.zlib}/lib
      fi
    '';
  };
in {
  # Nix
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = "experimental-features = nix-command flakes";
    settings = {
      cores = 4;
      max-jobs = 4;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise.automatic = true;
  };
  nixpkgs.overlays = [
    (import ./overlays/toluapp.nix)
    # Patch butler to avoid build failure in nixpkgs (sevenzip-go glue.c).
    (import ./overlays/butler-patch.nix)
    (import ./overlays/ha-ac-infinity.nix)
    (import ./overlays/ha-bambulab.nix)
    (import ./overlays/wvkbd.nix)
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    dhcpcd
    networkmanager
    tailscale
    cloudflare-warp
    neovim
    ripgrep
    wget
    git
    fastfetch

    fzf
    nodejs
    openssh
    lm_sensors
    jq

    fx
    unzip
    unrar
    zlib
    sshfs
    lf

    pulsemixer
    spotify-player
    # Codex CLI needs zlib at runtime for libz.so.1.
    codexCli
  ];

  programs = {
    git.enable = true;
    zsh.enable = true;
  };

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  services.automatic-timezoned.enable = true;

  # Networking
  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.cloudflare-warp.enable = true;

  # Power
  services.upower.enable = true;

  # Ledger
  hardware.ledger.enable = true;

  # QMK dev
  hardware.keyboard.qmk.enable = true;

  # User
  users.users.brandon = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"]; # Enable sudo + NetworkManager without admin auth.
    packages = with pkgs; [
      tree
    ];
    shell = pkgs.zsh;
  };

  # Allow SSH for brandon
  services.openssh = {
    enable = true;
    extraConfig = ''
      AllowUsers brandon
    '';
    settings = {
      PermitRootLogin = "no";
    };
  };

  # Latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
