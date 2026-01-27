self: super: {
  home-assistant-custom-components =
    super.home-assistant-custom-components
    // {
      bambu_lab = super.buildHomeAssistantComponent rec {
        owner = "greghesp";
        domain = "bambu_lab";
        version = "2.2.19";

        src = super.fetchFromGitHub {
          inherit owner;
          repo = "ha-bambulab";
          rev = "v${version}";
          hash = "sha256-BRTbo9v9a4iCkrgVfyFzZXZS4ogDr+Kkx9qz8bhAaDc=";
        };

        dependencies = with super.python3Packages; [
          beautifulsoup4
        ];

        meta = with super.lib; {
          description = "Bambu Lab integration for Home Assistant";
          homepage = "https://github.com/greghesp/ha-bambulab";
          license = licenses.mit;
        };
      };
    };
}
