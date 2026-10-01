{writeShellApplication, python3, curl}:
writeShellApplication {
  name = "update-chatgpt";
  runtimeInputs = [python3 curl];
  text = ''
    exec python3 ${./update.py} "$@"
  '';
}
