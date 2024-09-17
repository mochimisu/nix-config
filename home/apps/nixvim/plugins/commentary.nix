{
  programs.nixvim.plugins.commentary.enable = true;
  # gc, gcc, etc
  programs.nixvim.keymaps = [
    {
      mode = ["n" "i"];
      key = "<C-l>";
      action = "<cmd>Commentary<CR>";
    }
    {
      mode = ["v"];
      key = "<C-l>";
      action = ":Commentary<CR>";
    }
  ];
}
