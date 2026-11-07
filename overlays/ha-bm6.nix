_: super: {
  home-assistant-custom-components = super.home-assistant-custom-components // {
    bm6 = super.buildHomeAssistantComponent {
      owner = "Rafciq";
      domain = "bm6";
      version = "1.0.3";
      src = super.fetchFromGitHub {
        owner = "Rafciq";
        repo = "BM6";
        rev = "53437905346a0da5f2a6aa62bed3402a0b40bb43";
        hash = "sha256-sqxkv2mUQEVOHq4KAVMlKJV3msQZT7WWRIF1LjbbyZs=";
      };
      patches = [ ./ha-bm6-telemetry.patch ./ha-bm6-state.patch ./ha-bm6-last-seen.patch ];
      # The container copies the component, not Nix Python dependencies. Declare
      # the imported Crypto module in its manifest so HA installs the pinned wheel.
      dependencies = [ super.python3Packages.pycryptodome ];
      postPatch = ''
        substituteInPlace custom_components/bm6/manifest.json \
          --replace-fail '"requirements": []' '"requirements": ["pycryptodome==3.23.0"]'
      '';
      meta = with super.lib; {
        description = "BM6 / ANCEL BM200 Bluetooth battery telemetry for Home Assistant";
        homepage = "https://github.com/Rafciq/BM6";
        license = licenses.mit;
      };
    };
  };
}
