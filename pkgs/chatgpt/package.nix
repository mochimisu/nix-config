{ lib, stdenv, fetchurl, dpkg, autoPatchelfHook, makeWrapper, wrapGAppsHook3
, alsa-lib, at-spi2-core, cairo, cups, dbus, expat, gdk-pixbuf, glib, gtk3
, libgbm, libGL, libnotify, libpulseaudio, libsecret, libusb1, libxcb
, libxkbcommon, libx11, libxcomposite, libxdamage, libxext, libxfixes, libxrandr
, nspr, nss, openssl, pango, systemdLibs, tpm2-tss, qt5, qt6
, vulkan-loader, wayland, xdg-utils, bubblewrap, python3, nodejs
}:
let
  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-lJjkFxMaJ4vONb//YnXSUsDTMvF6/AMT4LeCdJ9NNIo=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-6Tger3kzedDwAlAChvxuggrQ+8Jz/5WCaKhJzVAOb/k=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in stdenv.mkDerivation rec {
  pname = "chatgpt";
  version = "26.1002.52244";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_${source.arch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper wrapGAppsHook3 python3 nodejs ];
  buildInputs = [
    alsa-lib at-spi2-core cairo cups dbus expat gdk-pixbuf glib gtk3
    libgbm libGL libnotify libpulseaudio libsecret libusb1 libxcb
    libxkbcommon libx11 libxcomposite libxdamage libxext libxfixes libxrandr
    nspr nss openssl pango systemdLibs tpm2-tss stdenv.cc.cc.lib
    (lib.getLib qt5.qtbase) (lib.getLib qt6.qtbase)
  ];
  # Libraries loaded with dlopen do not appear in ELF NEEDED entries.
  runtimeDependencies = map lib.getLib [
    libGL libnotify libpulseaudio libsecret systemdLibs vulkan-loader wayland
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  dontWrapGApps = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin" "$out/share"
    # Nix-store assets are read-only. Normalize only fresh runtime copies and
    # the data files the app customizes, preserving executable permissions.
    node ${./test-bundled-copy.cjs} ${./prepare-bundled-copy.cjs}
    python ${./patch-bundled-copy.py} \
      usr/lib/chatgpt/resources/app.asar ${./prepare-bundled-copy.cjs}
    cp -a usr/lib/chatgpt "$out/lib/"
    cp -a usr/share/applications usr/share/pixmaps usr/share/metainfo "$out/share/"

    # These optional node prebuilds target Android or musl, not Nix's glibc.
    find "$out/lib/chatgpt" -type f \( -path '*/prebuilds/*musl*' -o -path '*/prebuilds/android-*/*' \) -delete

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt' "Exec=$out/bin/chatgpt"
    runHook postInstall
  '';

  preFixup = ''
    # sharp keeps libvips in a sibling npm package outside normal library paths.
    addAutoPatchelfSearchPath "$out/lib/chatgpt"
    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils bubblewrap ]}
  '';

  meta = {
    description = "Official ChatGPT desktop app with Codex";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames sources;
    mainProgram = "chatgpt";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
