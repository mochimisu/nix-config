{pkgs, ...}: {
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
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    dhcpcd
    networkmanager
    neovim
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
    sshfs
    lf

    pulsemixer
    conky
    spotify-player
    codex
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

  # Power
  services.upower.enable = true;

  # Ledger
  hardware.ledger.enable = true;

  # QMK dev
  hardware.keyboard.qmk.enable = true;

  # User
  users.users.brandon = {
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
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
