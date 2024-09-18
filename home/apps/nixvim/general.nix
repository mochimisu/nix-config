{
  programs.nixvim.opts = {
    tabstop = 4;
    shiftwidth = 4;
    expandtab = true;

    ls = 2;
    showcmd = true;
    ignorecase = true;

    ruler = true;
    number = true;
    relativenumber = true;
    colorcolumn = "80";
    listchars = {
      tab = "»·";
      trail = "·";
    };
    conceallevel = 0;
  };
}
