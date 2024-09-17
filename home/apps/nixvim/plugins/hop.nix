{
  programs.nixvim.plugins.hop.enable = true;
  programs.nixvim.keymaps = [
    {
      mode = ["n"];
      key = "<leader>w";
      action = "<cmd>HopWordAC<CR>";
    }
    {
      mode = ["n"];
      key = "<leader>b";
      action = "<cmd>HopWordBC<CR>";
    }
  ];
}
