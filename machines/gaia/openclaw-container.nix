{ config, inputs, lib, ... }:
let
  containerName = "gaiaclaw";
  openclawUser = "openclaw";
  openclawHome = "/var/lib/openclaw";
  hostMountRoot = "/home/brandon/containers/${containerName}";
  hostContainerRoot = "/var/lib/nixos-containers/${containerName}";
in {
  systemd.tmpfiles.rules = [
    "d /home/brandon/containers 0755 brandon users -"
    "d ${hostMountRoot} 0755 brandon users -"
    "L+ ${hostMountRoot}/rootfs - brandon users - ${hostContainerRoot}"
  ];

  containers.${containerName} = {
    autoStart = true;
    privateNetwork = true;
    macvlans = [ "enp5s0" ];
    extraVeths.host = {
      hostAddress = "169.254.254.1";
      localAddress = "169.254.254.2";
    };

    config = { pkgs, ... }: {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

      networking.hostName = containerName;
      networking.useDHCP = lib.mkForce true;
      networking.hosts."169.254.254.1" = [ "gaia-host" ];
      networking.firewall.allowedTCPPorts = [ 18789 ];

      nixpkgs.overlays = [
        inputs.nix-openclaw.overlays.default
      ];

      users.users.${openclawUser} = {
        isNormalUser = true;
        home = openclawHome;
        createHome = true;
        description = "Openclaw service user";
        linger = true;
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-bak";
        users.${openclawUser} = {
          imports = [
            inputs.nix-openclaw.homeManagerModules.openclaw
          ];

          home = {
            username = openclawUser;
            homeDirectory = openclawHome;
            stateVersion = "24.11";
          };

          programs.home-manager.enable = true;

          home.file = {
            ".openclaw/docs/reference/templates/AGENTS.md".source =
              ./openclaw-documents/AGENTS.md;
            ".openclaw/docs/reference/templates/BOOTSTRAP.md".source =
              ./openclaw-documents/BOOTSTRAP.md;
            ".openclaw/docs/reference/templates/HEARTBEAT.md".source =
              ./openclaw-documents/HEARTBEAT.md;
            ".openclaw/docs/reference/templates/IDENTITY.md".source =
              ./openclaw-documents/IDENTITY.md;
            ".openclaw/docs/reference/templates/SOUL.md".source =
              ./openclaw-documents/SOUL.md;
            ".openclaw/docs/reference/templates/TOOLS.md".source =
              ./openclaw-documents/TOOLS.md;
            ".openclaw/docs/reference/templates/USER.md".source =
              ./openclaw-documents/USER.md;
          };

          programs.openclaw = {
            enable = true;
            launchd.enable = false;
            exposePluginPackages = false;
            documents = ./openclaw-documents;

            firstParty = {
              summarize.enable = true;
              oracle.enable = true;
            };

            instances.default = {
              enable = true;
              launchd.enable = false;
              systemd.enable = false;
              logPath = "${openclawHome}/.openclaw/openclaw-gateway.log";
              config = {
                gateway = {
                mode = "local";
                bind = "lan";
                tls = {
                  enabled = true;
                  autoGenerate = true;
                };
                auth = {
                  mode = "token";
                  # Set OPENCLAW_GATEWAY_TOKEN in ${openclawHome}/openclaw.env.
                };
                };

                agents = {
                  defaults = {
                    model = {
                      primary = "openai/gpt-5.2-codex";
                    };
                  };
                  list = [
                    {
                      id = "main";
                      default = true;
                      model = "openai/gpt-5.2-codex";
                    }
                  ];
                };

                channels.discord = {
                  enabled = true;
                  groupPolicy = "allowlist";
                  dm = {
                    enabled = true;
                    policy = "allowlist";
                    allowFrom = [ "88427327289040896" ];
                  };
                  guilds."319950594687107093" = {
                    users = [ "88427327289040896" ];
                    requireMention = false;
                    channels."1467033450983850140" = {
                      allow = true;
                      requireMention = false;
                    };
                  };
                };
              };
            };

            # Fill in programs.openclaw.config + plugins once secrets exist.
            # Use an env file (OPENCLAW_GATEWAY_TOKEN, provider keys, etc.)
            # to avoid storing secrets in the Nix store.
          };
        };
      };

      systemd.services.openclaw-gateway = {
        description = "Openclaw gateway (system)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" "home-manager-openclaw.service" ];
        after = [ "network-online.target" "home-manager-openclaw.service" ];
        serviceConfig = {
          Type = "simple";
          User = openclawUser;
          Group = "users";
          WorkingDirectory = "${openclawHome}/.openclaw";
          ExecStart = "${pkgs.openclaw}/bin/openclaw gateway --port 18789";
          EnvironmentFile = "-${openclawHome}/openclaw.env";
          Environment = [
            "HOME=${openclawHome}"
            "OPENCLAW_CONFIG_PATH=${openclawHome}/.openclaw/openclaw.json"
            "OPENCLAW_STATE_DIR=${openclawHome}/.openclaw"
            "OPENCLAW_NIX_MODE=1"
            "MOLTBOT_CONFIG_PATH=${openclawHome}/.openclaw/openclaw.json"
            "MOLTBOT_STATE_DIR=${openclawHome}/.openclaw"
            "MOLTBOT_NIX_MODE=1"
            "CLAWDBOT_CONFIG_PATH=${openclawHome}/.openclaw/openclaw.json"
            "CLAWDBOT_STATE_DIR=${openclawHome}/.openclaw"
            "CLAWDBOT_NIX_MODE=1"
            "PATH=/run/current-system/sw/bin:${pkgs.openssl}/bin"
            "NODE_PATH=${pkgs.openclaw-gateway}/lib/openclaw/node_modules/.pnpm/hasown@2.0.2/node_modules"
          ];
          Restart = "always";
          RestartSec = "1s";
          StandardOutput = "append:${openclawHome}/.openclaw/openclaw-gateway.log";
          StandardError = "append:${openclawHome}/.openclaw/openclaw-gateway.log";
        };
      };

      environment.systemPackages = [
        pkgs.openclaw
        pkgs.openssl
      ];

      environment.variables = {
        NODE_PATH =
          "${pkgs.openclaw-gateway}/lib/openclaw/node_modules/.pnpm/hasown@2.0.2/node_modules";
      };

      system.stateVersion = "24.11";
    };
  };
}
