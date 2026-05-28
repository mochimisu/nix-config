{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.gaiaOpenclaw;
  brandonUser = "brandon";
  openclawConfigUser = "openclaw";
  openclawRuntimeUser = brandonUser;
  openclawRuntimeHome = "/home/${brandonUser}";
  openclawHome = "/var/lib/openclaw";
  openclawState = "${openclawHome}/.openclaw";
  openclawConfig = "${openclawState}/openclaw.json";
  openclawEnv = "${openclawHome}/openclaw.env";
  openclawLog = "${openclawState}/openclaw-gateway.log";
  openclawWorkspace = "/home/${brandonUser}/stuff/openclaw";
  openclawManagedWorkspace = "${openclawState}/workspace";
  codexHome = "${openclawRuntimeHome}/.codex";
  codexOpenclawHome = "${openclawState}/agents/main/agent/codex-home";
  openclawGateway = pkgs.openclaw-gateway;

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
  codexAppServer = pkgs.writeShellScriptBin "codex-openclaw-app-server" ''
    export HOME='${openclawRuntimeHome}'
    export CODEX_HOME='${codexHome}'
    exec '${codexCli}/bin/codex' "$@"
  '';

  openclawGatewayStart = pkgs.writeShellScript "openclaw-gateway-start" ''
    set -euo pipefail
    set -a
    . '${openclawEnv}'
    set +a
    exec ${openclawGateway}/bin/openclaw gateway --port 18789
  '';
  openclawGatewayPreStart = pkgs.writeShellScript "openclaw-gateway-pre-start" ''
    set -euo pipefail

    ${pkgs.coreutils}/bin/chgrp users '${openclawHome}'
    ${pkgs.coreutils}/bin/chgrp users '${openclawState}'
    ${pkgs.coreutils}/bin/chmod 0770 '${openclawHome}'
    ${pkgs.coreutils}/bin/chmod 0770 '${openclawState}'
    ${pkgs.coreutils}/bin/install -d -m 0700 -o '${openclawRuntimeUser}' -g users '${codexHome}'
    ${pkgs.coreutils}/bin/install -d -m 0770 -o '${openclawRuntimeUser}' -g users '${codexOpenclawHome}'
    ${pkgs.findutils}/bin/find '${openclawState}' -xdev -type d -exec ${pkgs.coreutils}/bin/chgrp users {} +
    ${pkgs.findutils}/bin/find '${openclawState}' -xdev -type f -exec ${pkgs.coreutils}/bin/chgrp users {} +
    ${pkgs.findutils}/bin/find '${openclawState}' -xdev -type d -exec ${pkgs.coreutils}/bin/chmod 0770 {} +
    ${pkgs.findutils}/bin/find '${openclawState}' -xdev -type f -exec ${pkgs.coreutils}/bin/chmod 0660 {} +
    if [ -f '${codexHome}/auth.json' ]; then
      ${pkgs.coreutils}/bin/ln -sfnT '${codexHome}/auth.json' '${codexOpenclawHome}/auth.json'
    fi
    if [ -f '${codexHome}/config.toml' ]; then
      ${pkgs.coreutils}/bin/ln -sfnT '${codexHome}/config.toml' '${codexOpenclawHome}/config.toml'
    fi

    if [ ! -f '${openclawEnv}' ]; then
      umask 027
      token="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
      tmp="$(${pkgs.coreutils}/bin/mktemp '${openclawHome}/openclaw.env.XXXXXX')"
      printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$token" > "$tmp"
      ${pkgs.coreutils}/bin/chmod 0660 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" '${openclawEnv}'
    fi

    ${pkgs.coreutils}/bin/chmod 0660 '${openclawEnv}'
  '';
in {
  options.services.gaiaOpenclaw.enable =
    lib.mkEnableOption "Openclaw on the Gaia host";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      inputs.nix-openclaw.overlays.default
      (final: prev: {
        openclaw-gateway = prev.openclaw-gateway.overrideAttrs (old: {
          pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
            outputHash = "sha256-j0vTmAihVbg+rQb3DBYXFhcZZV7Z6ntypKwZyt/Qa7s=";
          });
          patches =
            (old.patches or [])
            ++ [
              ./openclaw-patches/codex-app-server-partial-replies.patch
            ];
        });
        openclaw = prev.openclaw.overrideAttrs (old: {
          env =
            (old.env or {})
            // {
              OPENCLAW_GATEWAY_BIN = "${final.openclaw-gateway}/bin/openclaw";
            };
        });
      })
    ];

    networking.firewall.allowedTCPPorts = [18789];

    users.users.${openclawConfigUser} = {
      isSystemUser = true;
      group = "users";
      home = openclawHome;
      homeMode = "0770";
      createHome = true;
      description = "Openclaw config owner";
      shell = pkgs.bashInteractive;
    };

    systemd.tmpfiles.rules = [
      "d ${openclawHome} 0770 ${openclawConfigUser} users - -"
      "d ${openclawState} 0770 ${openclawConfigUser} users - -"
      "d ${openclawWorkspace} 0770 ${brandonUser} users - -"
      "z ${openclawHome} 0770 ${openclawConfigUser} users - -"
      "z ${openclawState} 0770 ${openclawConfigUser} users - -"
    ];

    home-manager.users.${openclawConfigUser} = {
      imports = [
        inputs.nix-openclaw.homeManagerModules.openclaw
      ];

      home = {
        username = openclawConfigUser;
        homeDirectory = openclawHome;
        stateVersion = "24.11";
      };

      programs.home-manager.enable = true;

      home.file = {
        ".openclaw/openclaw.json".force = true;
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
        systemd.enable = false;
        exposePluginPackages = false;
        documents = ./openclaw-documents;

        bundledPlugins = {
          sag.enable = true;
          gogcli.enable = true;
        };

        instances.default = {
          enable = true;
          launchd.enable = false;
          systemd.enable = false;
          stateDir = openclawState;
          workspaceDir = openclawManagedWorkspace;
          configPath = openclawConfig;
          logPath = openclawLog;
          config = {
            gateway = {
              mode = "local";
              bind = "lan";
              tls = {
                enabled = true;
                autoGenerate = true;
              };
              controlUi.allowedOrigins = [
                "http://localhost:18789"
                "http://127.0.0.1:18789"
                "http://gaia:18789"
                "http://192.168.1.35:18789"
                "https://localhost:18789"
                "https://127.0.0.1:18789"
                "https://gaia:18789"
                "https://192.168.1.35:18789"
              ];
              auth = {
                mode = "token";
                # Set OPENCLAW_GATEWAY_TOKEN in ${openclawHome}/openclaw.env.
              };
            };

            agents = {
              defaults = {
                agentRuntime = {
                  id = "codex";
                };
                model = {
                  primary = "codex/gpt-5.5";
                };
                workspace = openclawWorkspace;
              };
              list = [
                {
                  id = "main";
                  default = true;
                  agentRuntime = {
                    id = "codex";
                  };
                  model = "codex/gpt-5.5";
                }
              ];
            };

            messages.groupChat.visibleReplies = "automatic";

            plugins.entries.codex = {
              enabled = true;
              config = {
                discovery = {
                  enabled = true;
                  timeoutMs = 10000;
                };
                appServer = {
                  transport = "stdio";
                  command = "${codexAppServer}/bin/codex-openclaw-app-server";
                  args = [
                    "app-server"
                    "--listen"
                    "stdio://"
                  ];
                  approvalPolicy = "never";
                  sandbox = "danger-full-access";
                  requestTimeoutMs = 120000;
                };
              };
            };

            channels.discord = {
              enabled = true;
              groupPolicy = "allowlist";
              dm.enabled = true;
              dmPolicy = "allowlist";
              allowFrom = ["88427327289040896"];
              ackReaction = "👀";
              ackReactionScope = "group-all";
              streaming = {
                mode = "partial";
                chunkMode = "length";
                preview = {
                  toolProgress = true;
                  commandText = "status";
                };
              };
              guilds."319950594687107093" = {
                users = ["88427327289040896"];
                requireMention = false;
                channels."1467033450983850140" = {
                  enabled = true;
                  requireMention = false;
                };
              };
            };
          };
        };
      };
    };

    systemd.services.openclaw-gateway = {
      description = "Openclaw gateway";
      wantedBy = ["multi-user.target"];
      wants = [
        "network-online.target"
        "home-manager-${openclawConfigUser}.service"
      ];
      after = [
        "network-online.target"
        "home-manager-${openclawConfigUser}.service"
      ];
      path = [
        pkgs.coreutils
        pkgs.git
        pkgs.openssl
        pkgs.zlib
        codexCli
      ];
      serviceConfig = {
        Type = "simple";
        User = openclawRuntimeUser;
        WorkingDirectory = openclawWorkspace;
        ExecStartPre = "+${openclawGatewayPreStart}";
        ExecStart = "${openclawGatewayStart}";
        EnvironmentFile = "-${openclawEnv}";
        Environment = [
          "HOME=${openclawRuntimeHome}"
          "OPENCLAW_CONFIG_PATH=${openclawConfig}"
          "OPENCLAW_STATE_DIR=${openclawState}"
          "OPENCLAW_NIX_MODE=1"
          "OPENCLAW_CLI_BACKEND_LOG_OUTPUT=1"
          "CODEX_HOME=${codexHome}"
          "NODE_PATH=${openclawGateway}/lib/openclaw/node_modules"
        ];
        Restart = "always";
        RestartSec = "1s";
        StandardOutput = "append:${openclawLog}";
        StandardError = "append:${openclawLog}";
      };
    };

    environment.systemPackages = [
      pkgs.openclaw
      pkgs.openssl
      codexCli
    ];

    environment.variables = {
      NODE_PATH = "${openclawGateway}/lib/openclaw/node_modules";
    };
  };
}
