{inputs, ...}:{
  imports = [
    ./general.nix
    ./keys.nix
    ./plugins
    ./filetype
  ];
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
  };
}
