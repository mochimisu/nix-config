{ config, lib, pkgs, osConfig ? {}, ... }:
let
  host = osConfig.networking.hostName or "standalone";
in {
  programs.wikimem = {
    enable = lib.mkDefault (pkgs.stdenv.hostPlatform.isLinux && host != "oai-dev" && (osConfig.services.wikimemClient.enable or true));
    url = "https://wikimem.bwang.dev/mcp";
    keyFile = osConfig.services.wikimemClient.keyFile or "${config.home.homeDirectory}/.config/wikimem/codex.key";
    localUrl = if host == "gaia" then "http://127.0.0.1:4783/mcp" else null;
    sshTarget = if host == "gaia" then null else "brandon@gaia";
  };
}
