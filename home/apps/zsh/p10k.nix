{
  programs.zsh.zplug.plugins = [
    {
      name = "romkatv/powerlevel10k";
      tags = [ as:theme depth:1 ];
    }
  ];

  home.sessionVariables = {
    POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD = "true";
  };

  home.file.".p10k.zsh".text = builtins.readFile ./p10k.zsh;
}
