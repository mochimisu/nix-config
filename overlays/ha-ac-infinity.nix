self: super: {
  home-assistant-custom-components =
    super.home-assistant-custom-components
    // {
      ac_infinity = super.buildHomeAssistantComponent rec {
        owner = "dalinicus";
        domain = "ac_infinity";
        version = "2.1.1";

        src = super.fetchFromGitHub {
          inherit owner;
          repo = "homeassistant-acinfinity";
          rev = version;
          hash = "sha256-aF7LtxJ5ZzmdGS2NoS6hdZPzD+zb9Ee9jnrAiKHv7NI=";
        };

        dependencies = [ ];

        meta = with super.lib; {
          description = "AC Infinity integration for Home Assistant";
          homepage = "https://github.com/dalinicus/homeassistant-acinfinity";
          license = licenses.mit;
        };
      };
    };
}
