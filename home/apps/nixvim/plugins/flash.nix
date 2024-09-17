{
  programs.nixvim.plugins.flash = {
    enable = true;
    settings = {
    };
  };
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>/";
      action = "<cmd>lua require(\"flash\").jump()<CR>";
    }
    ];
}
