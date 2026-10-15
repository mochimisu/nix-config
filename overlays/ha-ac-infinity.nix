_: super: {
  home-assistant-custom-components =
    super.home-assistant-custom-components
    // {
      ac_infinity = super.buildHomeAssistantComponent rec {
        owner = "dalinicus";
        domain = "ac_infinity";
        version = "2.3.1";

        src = super.fetchFromGitHub {
          inherit owner;
          repo = "homeassistant-acinfinity";
          rev = version;
          hash = "sha256-ltuPPfHXerem51BT0gXJExQlW1F+9Zf16sztxi05HBE=";
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
