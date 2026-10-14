{
  config,
  lib,
  pkgs,
  ...
}: let
  hostName = config.networking.hostName;
  hostLabel = lib.toUpper hostName;
  sambaShares = builtins.attrNames (builtins.removeAttrs config.services.samba.settings ["global"]);
  sambaShare = lib.head sambaShares;
  statsMounts = ["/"] ++ lib.optionals (config.fileSystems ? "/earth") ["/earth"];
  statsMountsJson = builtins.toJSON statsMounts;
  btrfsMounts = builtins.filter (mount: (config.fileSystems.${mount}.fsType or "") == "btrfs") (builtins.attrNames config.fileSystems);
  btrfsMountsJson = builtins.toJSON btrfsMounts;
  homepageListen = [
    # OTBR's own web process is moved to 127.0.0.1:8080 in
    # home-assistant/default.nix, so nginx can own normal HTTP everywhere.
    { addr = "0.0.0.0"; port = 80; }
    { addr = "[::]"; port = 80; extraParameters = ["ipv6only=on"]; }
  ];
  otbrUpstreamPort = 8080;
  otbrWebPort = 8088;
  matterjsWebPort = config.gaia.homeAssistant.matterjs.port;
  proxiedServiceHeaders = prefix: ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Prefix ${prefix};
    proxy_set_header Accept-Encoding "";
    proxy_redirect off;
  '';
  matterLayerSubstitutions = ''
    sub_filter_once off;
    sub_filter_types text/html application/javascript text/javascript;
    sub_filter 'src="/assets/' 'src="/matter-layer/assets/';
    sub_filter 'href="/assets/' 'href="/matter-layer/assets/';
    sub_filter 'src="/src/' 'src="/matter-layer/src/';
    sub_filter 'from "/src/' 'from "/matter-layer/src/';
    sub_filter 'import "/src/' 'import "/matter-layer/src/';
    sub_filter 'src="/@vite/' 'src="/matter-layer/@vite/';
    sub_filter '"/@vite/' '"/matter-layer/@vite/';
    sub_filter '"/@fs/' '"/matter-layer/@fs/';
    sub_filter 'from "/@fs/' 'from "/matter-layer/@fs/';
    sub_filter 'import "/@fs/' 'import "/matter-layer/@fs/';
    sub_filter '"/api/' '"/matter-layer/api/';
    sub_filter 'fetch("/api/' 'fetch("/matter-layer/api/';
    sub_filter '`/api/' '`/matter-layer/api/';
    sub_filter 'host}/events' 'host}/matter-layer/events';
  '';
  # Bump when response rewrites change: upstream asset hashes do not include them.
  blackvueAssetPrefix = "/blackvue/proxy-v2/assets/";
  blackvueSubstitutions = ''
    sub_filter_once off;
    sub_filter_types text/html application/javascript text/javascript application/json;
    sub_filter 'src="/assets/' 'src="${blackvueAssetPrefix}';
    sub_filter 'href="/assets/' 'href="${blackvueAssetPrefix}';
    # Cover JS string/template literals and all URL fields returned in JSON,
    # including index, compatibility playback, thumbnails, and vehicle art.
    sub_filter '"/api/' '"/blackvue/api/';
    sub_filter '`/api/' '`/blackvue/api/';
  '';
  otbrWebListen = [
    { addr = "0.0.0.0"; port = otbrWebPort; }
    { addr = "[::]"; port = otbrWebPort; extraParameters = ["ipv6only=on"]; }
  ];
  renderTemplate = file: values:
    lib.replaceStrings
      (map (name: "@${name}@") (builtins.attrNames values))
      (builtins.attrValues values)
      (builtins.readFile file);
  statsCollector = pkgs.writeTextFile {
    name = "gaia-homepage-stats.py";
    executable = true;
    text = renderTemplate ./homepage/stats.py.in {
      python = "${pkgs.python3}";
      coreutils = "${pkgs.coreutils}";
      btrfs = "${pkgs.btrfs-progs}";
      procps = "${pkgs.procps}";
      iproute2 = "${pkgs.iproute2}";
      inherit statsMountsJson btrfsMountsJson;
    };
  };
  homepage = pkgs.writeTextDir "index.html" (renderTemplate ./homepage/index.html {
    inherit hostName hostLabel sambaShare;
    matterjsWebPort = toString matterjsWebPort;
    otbrWebPort = toString otbrWebPort;
    fileDispatchCard = lib.optionalString config.services.gaiaMedia.enable
      (builtins.readFile ./homepage/file-dispatch.html);
  });
in {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts.gaia-home = {
      default = true;
      listen = homepageListen;
      root = homepage;
      locations."= /stats.json" = {
        alias = "/run/gaia-homepage/stats.json";
        extraConfig = ''
          add_header Cache-Control "no-store";
          add_header X-Content-Type-Options nosniff;
        '';
      };
      locations."/stats-events" = {
        proxyPass = "http://127.0.0.1:8090";
        extraConfig = ''
          proxy_buffering off;
          proxy_cache off;
          add_header Cache-Control "no-store";
          add_header X-Accel-Buffering no;
          add_header X-Content-Type-Options nosniff;
        '';
      };
      locations."= /matter-layer" = {
        return = "302 /matter-layer/";
      };
      locations."/matter-layer/" = {
        proxyPass = "http://127.0.0.1:3010/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/assets/" = {
        proxyPass = "http://127.0.0.1:3010/assets/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/src/" = {
        proxyPass = "http://127.0.0.1:3010/src/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/@vite/" = {
        proxyPass = "http://127.0.0.1:3010/@vite/";
        proxyWebsockets = true;
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/@fs/" = {
        proxyPass = "http://127.0.0.1:3010/@fs/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/node_modules/" = {
        proxyPass = "http://127.0.0.1:3010/node_modules/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/api/" = {
        proxyPass = "http://127.0.0.1:3010/api/";
        extraConfig = proxiedServiceHeaders "/matter-layer";
      };
      locations."/matter-layer/events" = {
        proxyPass = "http://127.0.0.1:3010/events";
        proxyWebsockets = true;
        extraConfig = proxiedServiceHeaders "/matter-layer";
      };
      locations."= /blackvue" = {
        return = "302 /blackvue/";
      };
      locations."/blackvue/" = {
        proxyPass = "http://127.0.0.1:3000/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions;
      };
      locations.${blackvueAssetPrefix} = {
        proxyPass = "http://127.0.0.1:3000/assets/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions + ''
          proxy_hide_header Cache-Control;
          add_header Cache-Control "private, no-cache" always;
          add_header X-Content-Type-Options nosniff;
        '';
      };
      locations."/blackvue/assets/" = {
        proxyPass = "http://127.0.0.1:3000/assets/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions;
      };
      locations."/blackvue/api/" = {
        proxyPass = "http://127.0.0.1:3000/api/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions;
      };
      locations."= /seed-capital" = {
        return = "302 /seed-capital/";
      };
      locations."/seed-capital/" = {
        proxyPass = "http://127.0.0.1:4317/";
        extraConfig = ''
          # The app natively supports this prefix; no fragile JS rewriting.
          # Preserve the real Origin for the app's trusted-proxy checks.
          proxy_set_header Host 127.0.0.1:4317;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Prefix /seed-capital;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Authorization $http_authorization;
          proxy_buffering off;
          proxy_cache off;
          proxy_redirect off;
          client_max_body_size 64k;
        '';
      };
      locations."= /jellyfin" = {
        return = "302 /jellyfin/";
      };
      locations."/jellyfin/" = {
        proxyPass = "http://127.0.0.1:8096/";
        proxyWebsockets = true;
        extraConfig = proxiedServiceHeaders "/jellyfin";
      };
      locations."= /otbr" = {
        return = "302 /otbr/";
      };
      locations."/otbr/" = {
        proxyPass = "http://127.0.0.1:${toString otbrUpstreamPort}/";
        extraConfig = proxiedServiceHeaders "/otbr";
      };
      locations."= /matterjs" = {
        return = "302 /matterjs/";
      };
      locations."/matterjs/" = {
        proxyPass = "http://127.0.0.1:${toString matterjsWebPort}/";
        proxyWebsockets = true;
        extraConfig = proxiedServiceHeaders "/matterjs";
      };
      extraConfig = ''
        add_header X-Content-Type-Options nosniff;
      '';
    };

    virtualHosts.otbr-web = {
      listen = otbrWebListen;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString otbrUpstreamPort}";
      };
      extraConfig = ''
        add_header X-Content-Type-Options nosniff;
      '';
    };
  };

  systemd.services.gaia-homepage-stats = {
    description = "Gaia homepage live stats writer";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    serviceConfig = {
      ExecStart = statsCollector;
      Restart = "always";
      RestartSec = "2s";
      RuntimeDirectory = "gaia-homepage";
      RuntimeDirectoryMode = "0755";
    };
  };

  networking.firewall.allowedTCPPorts = [80 otbrWebPort];
  # Direct agent access is LAN-only; the existing homepage also proxies it.
  networking.firewall.interfaces.enp5s0.allowedTCPPorts = [4317];
}
