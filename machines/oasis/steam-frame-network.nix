# Oasis-only settings for the existing Comet pairing. No pairing material here.
{lib, ...}: let
  peer = "10.35.78.1/32";
  interface = "wlan0"; # Verified USB 28de:2432, driver rtw89_8852cu.
  rules = [
    { protocol = "tcp"; port = 27036; }
    { protocol = "tcp"; port = 27037; }
    { protocol = "udp"; port = 27031; }
  ];
  args = rule: "-i ${interface} -s ${peer} -p ${rule.protocol} --dport ${toString rule.port} -m comment --comment comet-frame-dongle -j nixos-fw-accept";
in {
  # User confirmed physical location in the US. Preserve normal regulatory
  # restrictions; this is the standard cfg80211 country hint, not an override.
  boot.kernelParams = ["cfg80211.ieee80211_regdom=US"];

  # Do not enable Steam's broad all-interface Remote Play firewall option.
  # Comet's AP address was rechecked on 2026-10-07; ordinary LAN is excluded.
  networking.firewall.extraCommands = lib.mkAfter (lib.concatMapStringsSep "\n" (rule: ''
    iptables -w -C nixos-fw ${args rule} 2>/dev/null || iptables -w -I nixos-fw 1 ${args rule}
  '') rules);
  networking.firewall.extraStopCommands = lib.mkAfter (lib.concatMapStringsSep "\n" (rule: ''
    iptables -w -D nixos-fw ${args rule} 2>/dev/null || true
  '') rules);
}
