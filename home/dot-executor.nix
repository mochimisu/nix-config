# Private login state stays mutable and outside the Nix store.
{ config, lib, pkgs, inputs, ... }: let
  cfg = config.services.dot-executor;
  home = config.home.homeDirectory;
  catalog = import ../common-packages.nix { inherit pkgs inputs; };
in {
  options.services.dot-executor = {
    enable = lib.mkEnableOption "the headless dot executor for an already-approved computer";
    environmentId = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9_-]{0,255}";
      description = "Existing server-issued identity for this computer. This is not a credential or a new enrollment.";
    };
    hostName = lib.mkOption {
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9_.-]*";
      description = "Actual hostname authorized for the environment ID; checked at runtime.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/dot-executor/package.nix { codex = catalog.codexCli; };
      description = "Dot executor package using the locked native Codex CLI.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = pkgs.stdenv.hostPlatform.isLinux;
      message = "services.dot-executor requires Linux and a systemd user manager.";
    }];
    home.packages = [ cfg.package ];
    systemd.user.services.dot-executor = {
      Unit = {
        Description = "Headless dot executor (${cfg.hostName})";
        ConditionPathExists = "${home}/.local/share/dot-executor/auth.json";
        # A boot-time outage may outlast systemd's default retry window.
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "simple";
        WorkingDirectory = home;
        Environment = [
          "HOME=${home}"
          "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:${home}/.local/bin:/usr/local/bin:/usr/bin:/bin"
        ];
        ExecStart = "${lib.getExe cfg.package} run --environment-id ${cfg.environmentId} --host ${cfg.hostName}";
        # Retry native process failures, including early boot network failures.
        # Invalid setup and explicit access denials still require intervention.
        Restart = "on-failure";
        RestartSec = 30;
        RestartPreventExitStatus = [ 2 77 ];
        KillMode = "control-group";
        TimeoutStopSec = 20;
        UMask = "0077";
        StandardOutput = "journal";
        StandardError = "journal";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
