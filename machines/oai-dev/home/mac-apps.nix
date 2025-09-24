{ pkgs, lib, ... }:
let
  macAppWrappers = [
    {
      name = "Alacritty";
      kind = "app";
      path = "${pkgs.alacritty}/Applications/Alacritty.app";
    }
    {
      name = "Obsidian";
      kind = "bin";
      path = "${pkgs.obsidian}/bin/obsidian";
    }
  ];

  registerAppCommands =
    lib.concatMapStrings
      (app: ''
        register_app ${lib.escapeShellArg app.name} ${lib.escapeShellArg app.kind} ${lib.escapeShellArg app.path}
      '')
      macAppWrappers;
in {
  # Expose GUI apps for Finder by creating lightweight wrappers in /Applications/Home-Manager
  # that forward to the Nix-provided binaries.
  home.activation.linkMacApplications = lib.hm.dag.entryAfter ["writeBoundary"] ''
    dest_dir="/Applications/Home-Manager"
    case "$dest_dir" in
      /Applications/*) ;;
      *)
        echo "home-manager: refusing to manage apps outside /Applications"
        exit 1
        ;;
    esac

    ${pkgs.coreutils}/bin/rm -rf "$dest_dir"
    ${pkgs.coreutils}/bin/mkdir -p "$dest_dir"

    register_app() {
      local name="$1"
      local kind="$2"
      local path="$3"

      if [ -z "$name" ] || [ -z "$kind" ] || [ -z "$path" ]; then
        echo "home-manager: malformed app entry '$name::$kind::$path'"
        return
      fi

      local target="$dest_dir/$name.app"
      local contents="$target/Contents"
      local macos_dir="$contents/MacOS"
      local resources_dir="$contents/Resources"

      ${pkgs.coreutils}/bin/mkdir -p "$macos_dir" "$resources_dir"

      local launcher="$macos_dir/$name"
      local launch_cmd
      case "$kind" in
        bin)
          if [ ! -x "$path" ]; then
            echo "home-manager: skipped wrapping $name because $path was not executable"
            return
          fi
          launch_cmd="\"$path\" \"\$@\""
          ;;
        app)
          if [ ! -d "$path" ]; then
            echo "home-manager: skipped wrapping $name because $path was not an app bundle"
            return
          fi
          launch_cmd="/usr/bin/open -n \"$path\" --args \"\$@\""
          ;;
        *)
          echo "home-manager: unknown app kind '$kind' for $name"
          return
          ;;
      esac

      ${pkgs.coreutils}/bin/cat > "$launcher" <<EOF
#!/usr/bin/env bash
exec $launch_cmd
EOF
      ${pkgs.coreutils}/bin/chmod +x "$launcher"

      ${pkgs.coreutils}/bin/cat > "$contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$name</string>
  <key>CFBundleIdentifier</key>
  <string>com.home-manager.$name</string>
  <key>CFBundleName</key>
  <string>$name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
</dict>
</plist>
EOF

      /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$target"
    }

    ${registerAppCommands}
  '';
}
