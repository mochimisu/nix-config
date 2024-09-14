{inputs, ...}:{
  imports = [
    ./general.nix
    ./keys.nix
    ./plugins
  ];
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
  };
}
