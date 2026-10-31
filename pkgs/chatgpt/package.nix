{ lib, stdenv, fetchurl, dpkg, autoPatchelfHook, makeWrapper, wrapGAppsHook3
, alsa-lib, at-spi2-core, cairo, cups, dbus, expat, gdk-pixbuf, glib, gtk3
, libgbm, libGL, libnotify, libpulseaudio, libsecret, libusb1, libxcb
, libxkbcommon, libx11, libxcomposite, libxdamage, libxext, libxfixes, libxrandr
, nspr, nss, openssl, pango, systemdLibs, tpm2-tss, qt5, qt6
, vulkan-loader, wayland, xdg-utils, bubblewrap, python3, nodejs, patchelf
}:
let
  # 0.19.2 produces overlapping LOAD segments in the bundled Node 24 ELF,
  # causing SIGSEGV in glibc's dl_main before taskWorkspace/prepare can run.
  patchelfCompat = patchelf.overrideAttrs {
    version = "0.15.2";
    src = fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
  };
  sources = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-RITcK1T8CXi+sjuNjXF0lOTgtPvqsKh2c5EF5QtE3lo=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-50eNhPKTjdNz+mHFKw8gCwfWEOSJRwUr2K10dpt/0/s=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in stdenv.mkDerivation rec {
  pname = "chatgpt";
  version = "26.1023.51421";

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
    python ${./test-launcher.py} ${./launcher.py}
    node ${./test-bundled-copy.cjs} ${./prepare-bundled-copy.cjs}
    python ${./patch-bundled-copy.py} \
      usr/lib/chatgpt/resources/app.asar ${./prepare-bundled-copy.cjs} \
      ${./window-controls.py} ${./test-window-controls.cjs}
    cp -a usr/lib/chatgpt "$out/lib/"
    cp -a usr/share/applications usr/share/pixmaps usr/share/metainfo "$out/share/"

    # These optional node prebuilds target Android or musl, not Nix's glibc.
    find "$out/lib/chatgpt" -type f \( -path '*/prebuilds/*musl*' -o -path '*/prebuilds/android-*/*' \) -delete

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt' "Exec=$out/bin/chatgpt"
    runHook postInstall
  '';

  preFixup = ''
    # Use the compatible patcher for both stdenv and recursive autoPatchelf.
    export PATH="${lib.makeBinPath [ patchelfCompat ]}:$PATH"
    # sharp keeps libvips in a sibling npm package outside normal library paths.
    addAutoPatchelfSearchPath "$out/lib/chatgpt"
    makeWrapper "$out/lib/chatgpt/ChatGPT" "$out/lib/chatgpt/chatgpt-wrapped" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils bubblewrap ]}
    makeWrapper ${python3}/bin/python3 "$out/bin/chatgpt" \
      --add-flags "${./launcher.py} $out/lib/chatgpt/chatgpt-wrapped"
  '';

  # Test the shipped runtime after ELF fixups, not nixpkgs' build-time Node.
  # No display server, app session, or external connection is needed.
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/lib/chatgpt/resources/cua_node/bin/node" --version
    "$out/lib/chatgpt/resources/cua_node/bin/node" -e '
      const assert = require("node:assert/strict");
      const crypto = require("node:crypto");
      const net = require("node:net");
      const { privateKey, publicKey } = crypto.generateKeyPairSync("ed25519");
      const payload = Buffer.from("codex.taskWorkspace.prepare.v1");
      assert(crypto.verify(null, payload, publicKey, crypto.sign(null, payload, privateKey)));
      assert.equal(typeof net.createConnection, "function");
      console.log("Bundled task-workspace Node runtime passed");
    '
    runHook postInstallCheck
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
