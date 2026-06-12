{
  config,
  pkgs,
  inputs,
  lib,
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
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.websockets
  ]);
  pythonCli = pkgs.runCommand "python-cli" {} ''
    mkdir -p "$out/bin"
    ln -s ${pythonEnv}/bin/python3 "$out/bin/python3"
    ln -s ${pythonEnv}/bin/python3 "$out/bin/python"
  '';
  wikiskillDir = "/home/brandon/stuff/wikiskill";
  isGaia = config.networking.hostName == "gaia";
  enableWikiskillServices = builtins.elem config.networking.hostName [
    "gaia"
    "blackmoon"
  ];
  gaiaNixCachePublicKey = lib.strings.trim (builtins.readFile ./machines/gaia/nix-cache-pub-key.pem);
  uploadToGaiaNixCacheHook = pkgs.writeShellScript "upload-to-gaia-nix-cache" ''
    set -efu

    if [ -z "''${OUT_PATHS:-}" ]; then
      exit 0
    fi

    export PATH="${lib.makeBinPath [
      pkgs.coreutils
      pkgs.nix
      pkgs.openssh
    ]}"
    export NIX_SSHOPTS="-o BatchMode=yes -o ConnectTimeout=3 -o ConnectionAttempts=1"

    if ! ssh $NIX_SSHOPTS brandon@gaia true >/dev/null 2>&1; then
      echo "upload-to-gaia-nix-cache: gaia is not reachable over SSH; skipping $DRV_PATH" >&2
      exit 0
    fi

    if ! nix copy --to ssh://brandon@gaia $OUT_PATHS >&2; then
      echo "upload-to-gaia-nix-cache: failed to copy outputs for $DRV_PATH to gaia; continuing" >&2
    fi
  '';
in {
  imports = [
    ./obsidian-sync.nix
  ];

  # Nix
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = "experimental-features = nix-command flakes";
    settings = {
      cores = 4;
      max-jobs = 4;
      extra-substituters = [
        "http://gaia:5000"
      ];
      extra-trusted-public-keys = [
        gaiaNixCachePublicKey
      ];
      post-build-hook = lib.mkIf (!isGaia) uploadToGaiaNixCacheHook;
      trusted-users = lib.optional isGaia "brandon";
    };
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      n.flake = inputs.nixpkgs;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise.automatic = true;
  };

  services.nix-serve = lib.mkIf isGaia {
    enable = true;
    port = 5000;
    openFirewall = true;
    secretKeyFile = "/home/brandon/.local/state/nix-cache/gaia-cache-priv-key.pem";
  };

  nixpkgs.overlays = [
    (import ./overlays/toluapp.nix)
    (import ./overlays/ha-ac-infinity.nix)
    (import ./overlays/ha-bambulab.nix)
    (import ./overlays/wvkbd.nix)
    inputs.hyprgrass.overlays.default
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
    pythonCli
    openssh
    lm_sensors
    jq
    rclone
    sops
    proton-pass-cli

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
    nh = {
      enable = true;
      flake = "/home/brandon/stuff/nix-config";
    };
    nix-ld.enable = true;
    nix-index.enable = true;
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

  services.syncthing = {
    enable = true;
    user = "brandon";
    group = "users";
    dataDir = lib.mkDefault "/home/brandon/Sync";
    configDir = lib.mkDefault "/home/brandon/.config/syncthing";
    guiAddress = lib.mkDefault "127.0.0.1:8384";
    openDefaultPorts = true;
    overrideDevices = lib.mkDefault false;
    overrideFolders = lib.mkDefault false;
  };

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

  systemd.services = lib.mkIf enableWikiskillServices {
    wikiskill-dev = {
      description = "wikiskill wiki:dev";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      unitConfig.ConditionPathIsDirectory = wikiskillDir;
      path = with pkgs; [
        bash
        nodejs
        git
        coreutils
      ];
      serviceConfig = {
        Type = "simple";
        User = "brandon";
        Group = "users";
        WorkingDirectory = wikiskillDir;
        ExecStart = "${pkgs.nodejs}/bin/node ${wikiskillDir}/wiki/build.mjs --dev";
        Restart = "always";
        RestartSec = 5;
        TimeoutStopSec = "10s";
        Environment = [
          "HOME=/home/brandon"
        ];
      };
    };

    wikiskill-daily-daemon = {
      description = "wikiskill wiki:daily-daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      unitConfig.ConditionPathIsDirectory = wikiskillDir;
      path = with pkgs; [
        bash
        nodejs
        git
        coreutils
      ];
      serviceConfig = {
        Type = "simple";
        User = "brandon";
        Group = "users";
        WorkingDirectory = wikiskillDir;
        ExecStart = "${pkgs.nodejs}/bin/node ${wikiskillDir}/scripts/wiki-daily-daemon.mjs";
        Restart = "always";
        RestartSec = 5;
        SuccessExitStatus = [130 143];
        TimeoutStopSec = "10s";
        Environment = [
          "HOME=/home/brandon"
        ];
      };
    };
  };

  boot = {
    # Latest kernel
    kernelPackages = pkgs.linuxPackages_latest;
    tmp.cleanOnBoot = true;
  };
}
