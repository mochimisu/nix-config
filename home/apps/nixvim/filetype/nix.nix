{
  programs.nixvim.files = {
    "ftdetect/nix.lua".autoCmd = [
      {
        event = "FileType";
        pattern = "*.nix";
        command = "setlocal tabstop=2 shiftwidth=2 expandtab";
      }
    ];
  };
}
