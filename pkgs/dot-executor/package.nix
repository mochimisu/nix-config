{ lib, stdenvNoCC, python3, makeWrapper, codex }:
stdenvNoCC.mkDerivation {
  pname = "dot-executor";
  version = "2026-11-09";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./dot_executor.py ./tests ];
  };
  nativeBuildInputs = [ python3 makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  postPatch = ''
    substituteInPlace dot_executor.py \
      --replace-fail '@codex@' '${lib.getExe' codex "codex"}'
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME="$TMPDIR/test-home"
    mkdir -p "$HOME"
    python3 -m unittest discover -s tests -v
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    install -Dm644 dot_executor.py "$out/libexec/dot_executor.py"
    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe python3} "$out/bin/dot-executor" \
      --add-flags "$out/libexec/dot_executor.py"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test -x ${lib.getExe' codex "codex"}
    ${lib.getExe' codex "codex"} --version
    "$out/bin/dot-executor" --help >/dev/null
  '';
  meta = {
    description = "Native headless executor for an existing granted dot identity";
    mainProgram = "dot-executor";
    platforms = lib.platforms.linux;
  };
}
