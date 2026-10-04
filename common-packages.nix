# One package catalog for the existing NixOS modules and standalone SteamOS home.
# Service/driver/session configuration stays in the NixOS modules.
{pkgs, inputs}: let
  inherit (pkgs) lib;
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
  baseEntries = with pkgs; [
    { name = "dhcpcd"; package = dhcpcd; }
    { name = "networkmanager"; package = networkmanager; }
    { name = "tailscale"; package = tailscale; }
    { name = "cloudflare-warp"; package = cloudflare-warp; }
    { name = "neovim"; package = neovim; }
    { name = "ripgrep"; package = ripgrep; }
    { name = "wget"; package = wget; }
    { name = "git"; package = git; }
    { name = "fastfetch"; package = fastfetch; }
    { name = "fzf"; package = fzf; }
    { name = "nodejs"; package = nodejs; }
    { name = "python-cli"; package = pythonCli; }
    { name = "openssh"; package = openssh; }
    { name = "lm_sensors"; package = lm_sensors; }
    { name = "jq"; package = jq; }
    { name = "rclone"; package = rclone; }
    { name = "sops"; package = sops; }
    { name = "proton-pass-cli"; package = proton-pass-cli; }
    { name = "fx"; package = fx; }
    { name = "unzip"; package = unzip; }
    { name = "unrar"; package = unrar; }
    { name = "zlib"; package = zlib; }
    { name = "sshfs"; package = sshfs; }
    { name = "lf"; package = lf; }
    { name = "pulsemixer"; package = pulsemixer; }
    { name = "spotify-player"; package = spotify-player; }
    { name = "codex-cli"; package = codexCli; }
  ];
  guiEntries = with pkgs; [
    { name = "chromium"; package = (chromium.override {enableWideVine = true;}); }
    { name = "cliphist"; package = cliphist; }
    { name = "xdg-utils"; package = xdg-utils; }
    { name = "brightnessctl"; package = brightnessctl; }
    { name = "grim"; package = grim; }
    { name = "slurp"; package = slurp; }
    { name = "wf-recorder"; package = wf-recorder; }
    { name = "wl-clipboard"; package = wl-clipboard; }
    { name = "seahorse"; package = seahorse; }
    { name = "pulseaudio"; package = pulseaudio; }
    { name = "chatgpt"; package = (pkgs.callPackage ./pkgs/chatgpt/package.nix {}); }
    { name = "discord"; package = discord; }
    { name = "proton-pass"; package = proton-pass; }
    { name = "caprine"; package = caprine; }
    { name = "vlc"; package = vlc; }
    { name = "signal-desktop"; package = signal-desktop; }
    { name = "ani-cli"; package = ani-cli; }
    { name = "transmission-remote-gtk"; package = transmission-remote-gtk; }
    { name = "ledger-live-desktop"; package = ledger-live-desktop; }
    { name = "proton-vpn"; package = proton-vpn; }
    { name = "thunar"; package = thunar; }
    { name = "mangohud"; package = mangohud; }
    { name = "xivlauncher-rb"; package = inputs.nixos-xivlauncher-rb.packages.${pkgs.stdenv.hostPlatform.system}.default; }
    { name = "itch"; package = itch; }
    { name = "wine"; package = wine; }
    { name = "antimicrox"; package = antimicrox; }
    { name = "sc-controller"; package = sc-controller; }
    { name = "obs-studio"; package = obs-studio; }
    { name = "appimage-run"; package = appimage-run; }
    { name = "seventeenlands"; package = seventeenlands; }
    { name = "protonplus"; package = protonplus; }
  ];
  # The only exclusions here concern actual package/platform availability.
  classify = entry:
    if entry.name == "xivlauncher-rb" && !(builtins.hasAttr pkgs.stdenv.hostPlatform.system inputs.nixos-xivlauncher-rb.packages) then entry // { reason = "Upstream input has no output for this platform"; }
    else let
      availability = builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform entry.package && !(entry.package.meta.broken or false));
    in entry // {
      reason = if availability.success && availability.value then null else "Unavailable on this platform in the locked package set";
    };
  classified = map classify (baseEntries ++ guiEntries);
in {
  base = map (entry: entry.package) baseEntries;
  gui = map (entry: entry.package) guiEntries;
  fonts = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    liberation_ttf
    wqy_zenhei
    nerd-fonts.ubuntu-sans
    # coding font
    cascadia-code
    # general sans font
    montserrat
  ];
  sharedApps = map (entry: entry.package) (builtins.filter (entry: entry.reason == null) classified);
  exclusions = map (entry: {inherit (entry) name reason;}) (builtins.filter (entry: entry.reason != null) classified);
}
