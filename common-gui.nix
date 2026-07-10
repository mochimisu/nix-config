{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
  touchscreenVars = lib.attrByPath ["touchscreen"] {} config.variables;
  enableSddmKeyboard = touchscreenVars.sddmKeyboard or false;
  sddmKeyboardMaxWidth = touchscreenVars.sddmKeyboardMaxWidth or 1440;
  sddmKeyboardLayout =
    touchscreenVars.sddmKeyboardLayout
    or (
      if
        (config.services.xserver.xkb.layout or "") == "custom"
        && (config.services.xserver.xkb.variant or "") == "dvorak-custom"
      then "dvorak-custom"
      else "qwerty"
    );
  sddmKeyboardLayoutFile =
    if sddmKeyboardLayout == "dvorak-custom"
    then ./apps/qtvirtualkeyboard/layouts/en_US/dvorak-custom.qml
    else ./apps/qtvirtualkeyboard/layouts/en_US/main.qml;
  sddmKeyboardLayoutUrl = "file://${sddmKeyboardLayoutFile}";
  patchedQtVirtualKeyboard = pkgs.qt6.qtvirtualkeyboard.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        substituteInPlace "$out/lib/qt-6/qml/QtQuick/VirtualKeyboard/InputPanel.qml" \
          --replace-fail '        anchors.left: parent.left' '        width: Math.min(parent.width, ${toString sddmKeyboardMaxWidth})' \
          --replace-fail '        anchors.right: parent.right' '        anchors.horizontalCenter: parent.horizontalCenter'
        perl -0pi -e 's/        anchors\.left: parent\.left\n        anchors\.right: parent\.right\n        anchors\.bottom: parent\.bottom/        width: Math.min(parent.width, ${toString sddmKeyboardMaxWidth})\n        anchors.horizontalCenter: parent.horizontalCenter\n        anchors.bottom: parent.bottom/' \
          "$out/lib/qt-6/qml/QtQuick/VirtualKeyboard/Components/Keyboard.qml"
        perl -0pi -e 's/(                anchors\.bottomMargin: Math\.round\(style\.keyboardRelativeBottomMargin \* parent\.height\)\n)/$1\n                Binding {\n                    target: keyboardLayoutLoader.item\n                    property: "width"\n                    value: keyboardLayoutLoader.width\n                    when: keyboardLayoutLoader.item !== null\n                    restoreMode: Binding.RestoreNone\n                }\n\n                Binding {\n                    target: keyboardLayoutLoader.item\n                    property: "height"\n                    value: keyboardLayoutLoader.height\n                    when: keyboardLayoutLoader.item !== null\n                    restoreMode: Binding.RestoreNone\n                }\n/' \
          "$out/lib/qt-6/qml/QtQuick/VirtualKeyboard/Components/Keyboard.qml"
        substituteInPlace "$out/lib/qt-6/qml/QtQuick/VirtualKeyboard/Components/BaseKey.qml" \
          --replace-fail '    Layout.minimumWidth: keyPanel.implicitWidth' '    Layout.minimumWidth: 0'
        perl -0pi -e 's|    function updateLayout\(\) \{\n        var newLayout\n        newLayout = findLayout\(locale, layoutType\)\n        if \(!newLayout\.length\) \{\n            newLayout = findLayout\(locale, "main"\)\n        \}\n        layout = newLayout\n        inputLocale = locale\n        updateInputMethod\(\)\n    \}|    function updateLayout() {\n        layout = "${sddmKeyboardLayoutUrl}"\n        console.warn("SDDM QtVK layout forced to " + layout)\n        inputLocale = "en_US"\n        updateInputMethod()\n    }|' \
          "$out/lib/qt-6/qml/QtQuick/VirtualKeyboard/Components/Keyboard.qml"
        find "$out/lib/qt-6/qml/QtQuick/VirtualKeyboard" -name qmldir -print0 \
          | xargs -0 sed -i '/^prefer :\/qt-project\.org\/imports\/QtQuick\/VirtualKeyboard/d'
      '';
  });
  # pkgsPinned = import (builtins.fetchTarball {
  #   # walker broken on 2/13/2025, use a commit from 2/3/2025
  #   url = "https://github.com/NixOS/nixpkgs/archive/9d962cd4ad268f64d125aa8c5599a87a374af78a.tar.gz";
  #   sha256 = "sha256:1a1917f9qvg5agx2vhlsrhj3yyjrznpcnlkwcqk4ampzdby6nzhi";
  # }) { system = "x86_64-linux"; };
in {
  imports = [
    ./keymap.nix
    inputs.catppuccin.nixosModules.catppuccin
    inputs.flatpaks.nixosModules.nix-flatpak
  ];

  # Packages
  environment.systemPackages = with pkgs; [
    bluez
    mesa
    # greetd.tuigreet
    pkgs.hyprpaper
    networkmanagerapplet
    (chromium.override {enableWideVine = true;})
    cliphist
    xdg-utils
    brightnessctl

    grim
    slurp
    wf-recorder
    wl-clipboard
    inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.xdg-desktop-portal-hyprland

    hyprpolkitagent
    gnome-keyring
    # gnome-keyring management ui
    seahorse

    # for pactl
    pulseaudio

    # Apps
    # discord-canary
    # High CPU usage
    # vesktop
    discord
    proton-pass
    caprine
    hyprpicker
    vlc
    signal-desktop
    ani-cli
    transmission-remote-gtk
    ledger-live-desktop
    proton-vpn
    thunar

    # Games
    mangohud
    inputs.nixos-xivlauncher-rb.packages.${pkgs.stdenv.hostPlatform.system}.default
    parsec-bin
    itch
    wine
    gamescope
    antimicrox
    sc-controller
    obs-studio
    appimage-run
    seventeenlands
    protonplus
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";

    # steam and other electron apps to use wayland for better perf
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    # fullscreen render bug
    # WLR_DRM_NO_ATOMIC = "1";
  };

  programs = {
    steam = {
      enable = true;
      extest.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    gamemode.enable = true;
    hyprland = {
      enable = true;
      withUWSM = true;
    };
  };

  home-manager.extraSpecialArgs = {inherit inputs;};
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
  services.dbus.implementation = "broker";
  services.power-profiles-daemon.enable = true;

  # Fonts
  fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    liberation_ttf
    wqy_zenhei
    nerd-fonts.ubuntu-sans
    # coding font
    cascadia-code
    # general sans font
    montserrat
  ];

  # Touchpad support
  services.libinput.enable = true;

  # Gamepad remapping
  services.input-remapper.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.flatpak = {
    enable = lib.mkDefault true;
    packages = [
      {
        appId = "com.bambulab.BambuStudio";
        origin = "flathub";
      }
    ];
  };

  boot.kernelModules = [
    # Recent Proton titles are more stable when ntsync is available.
    "ntsync"
  ];

  # sddm
  services.xserver.enable = false;
  services.displayManager.sddm =
    {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = true;
    }
    // lib.optionalAttrs enableSddmKeyboard {
      settings = {
        General = {
          InputMethod = "qtvirtualkeyboard";
          GreeterEnvironment = "QT_VIRTUALKEYBOARD_STYLE=compact,QT_VIRTUALKEYBOARD_LAYOUT_PATH=/etc/xdg/qtvirtualkeyboard/layouts,QML2_IMPORT_PATH=/etc/xdg/qtvirtualkeyboard/qml,QML_DISABLE_DISK_CACHE=1";
        };
      };
      extraPackages = [
        patchedQtVirtualKeyboard
      ];
    };

  environment.etc = lib.mkIf enableSddmKeyboard {
    "xdg/qtvirtualkeyboard/layouts/en_US/main.qml".source = sddmKeyboardLayoutFile;
    "xdg/qtvirtualkeyboard/qml/QtQuick/VirtualKeyboard/Styles/compact/style.qml".source =
      ./apps/qtvirtualkeyboard/qml/QtQuick/VirtualKeyboard/Styles/compact/style.qml;
  };

  # login to start ssh-agent
  services.gnome.gnome-keyring.enable = true;
  security = {
    polkit.enable = true;
    pam = {
      services = {
        login.enableGnomeKeyring = true;
        sddm = {
          enable = true;
          enableGnomeKeyring = true;
        };
      };
    };
  };

  # catppuccin
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };
}
