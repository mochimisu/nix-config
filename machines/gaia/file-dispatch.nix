{ inputs, ... }:
{
  imports = [ inputs.gaia-file-dispatch.nixosModules.default ];
  # Prepared only. Security-sensitive service/proxy/folder activation awaits approval.
  services.gaiaMedia = {
    enable = false;
    deviceIds = {
      gaia = "XQIBVXP-GOKDEV5-SZ2JD43-VQTHAFK-XWEQW6R-JZUP7W3-OPG5OJ3-PCEO5AH";
      comet = "JM4ZRHI-OHZXM4I-UPEBQQQ-WNYIN2A-S4HWWMJ-5TXHZGN-YS5NGWN-7FD6KQA";
      oasis = "3R7C3XS-VLVI4G3-CLHAEKS-IRCFNV6-VH7TXY5-2UP7GPR-MCNSWRR-75R6YAG";
    };
  };
}
