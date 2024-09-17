{config, lib, ...}: {
  programs.nixvim = {
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    keymaps = let
    normal=
    lib.mapAttrsToList
    (key: action: {
     mode = "n";
     inherit action key;
     })
    {
      ";" = ":";
      ":" = ";";
      "Q" = "<nop>";
      ",cd" = ":cd %:p:h<CR>:pwd<CR>";
      "<leader>c" = "\"+y";
      "<leader>v" = "\"+p";
    };
    visual =
      lib.mapAttrsToList
      (key: action: {
       mode = "v";
       inherit action key;
       })
    {
      ";" = ":";
      ":" = ";";
      "<leader>c" = "\"+y";
      "<leader>v" = "\"+p";
    };
    in
    config.lib.nixvim.keymaps.mkKeymaps
    {}
    (normal ++ visual);
  };
}
