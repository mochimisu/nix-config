_: super: {
  home-assistant-custom-components =
    super.home-assistant-custom-components
    // {
      ac_infinity = super.buildHomeAssistantComponent rec {
        owner = "dalinicus";
        domain = "ac_infinity";
        version = "2.2.0";

        src = super.fetchFromGitHub {
          inherit owner;
          repo = "homeassistant-acinfinity";
          rev = version;
          hash = "sha256-TOXkNAxLXOSRV3H88EFXGAfeZ52QAGlzqdOWGS9WEG4=";
        };

        dependencies = [];

        meta = with super.lib; {
          description = "AC Infinity integration for Home Assistant";
          homepage = "https://github.com/dalinicus/homeassistant-acinfinity";
          license = licenses.mit;
        };
      };
    };
}
