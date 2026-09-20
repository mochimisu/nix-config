_: super: let
  haPythonPackages = super.home-assistant.python3Packages;
in {
  home-assistant-custom-components =
    super.home-assistant-custom-components
    // {
      bambu_lab = super.buildHomeAssistantComponent rec {
        owner = "greghesp";
        domain = "bambu_lab";
        version = "2.2.26";

        src = super.fetchFromGitHub {
          inherit owner;
          repo = "ha-bambulab";
          rev = "v${version}";
          hash = "sha256-9KsIzem7BjImUW+BTnAUYJ7CnU5bFpet7D2HhmOwTbA=";
        };

        dependencies = [
          haPythonPackages.beautifulsoup4
        ];

        meta = with super.lib; {
          description = "Bambu Lab integration for Home Assistant";
          homepage = "https://github.com/greghesp/ha-bambulab";
          license = licenses.mit;
        };
      };
    };
}
