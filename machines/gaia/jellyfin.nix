{pkgs, ...}: let
  jellyfinOrganizerPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.guessit
    pythonPackages.watchdog
  ]);

  jellyfinOrganizer = pkgs.writeText "jellyfin-organizer.py" ''
    import argparse
    import hashlib
    import json
    import os
    import re
    import signal
    import sys
    import time
    from pathlib import Path

    from guessit import guessit
    from watchdog.events import FileSystemEventHandler
    from watchdog.observers import Observer

    VIDEO_EXTENSIONS = {
        ".avi",
        ".m4v",
        ".mkv",
        ".mov",
        ".mp4",
        ".mpeg",
        ".mpg",
        ".ts",
        ".webm",
        ".wmv",
    }
    SKIP_DIRS = {
        ".stfolder",
        "@eadir",
        "apps",
        "etc",
        "games",
        "incomplete",
    }
    SKIP_NAME_RE = re.compile(r"(^|[ ._\[(])sample([ ._\])]|$)", re.IGNORECASE)
    SAFE_RE = re.compile(r"[<>:\"/\\|?*\x00-\x1f]")
    SPACE_RE = re.compile(r"\s+")


    def clean_name(value):
        text = str(value or "").strip()
        text = SAFE_RE.sub(" ", text)
        text = SPACE_RE.sub(" ", text)
        text = text.strip(" .-_")
        return text or "Unknown"


    def rel_hash(path):
        return hashlib.sha1(str(path).encode("utf-8")).hexdigest()[:10]


    def media_files(source_root):
        for path in source_root.rglob("*"):
            if not path.is_file():
                continue
            try:
                rel_parts = path.relative_to(source_root).parts
            except ValueError:
                continue
            if any(part in SKIP_DIRS for part in rel_parts[:-1]):
                continue
            if path.suffix.lower() not in VIDEO_EXTENSIONS:
                continue
            if SKIP_NAME_RE.search(path.stem):
                continue
            yield path


    def year_suffix(info):
        year = info.get("year")
        if isinstance(year, list):
            year = year[0] if year else None
        return f" ({year})" if year else ""


    def episode_number(value):
        if isinstance(value, list):
            return value[0] if value else None
        return value


    def format_episode_tag(season, episode):
        if season is None or episode is None:
            return None
        if isinstance(episode, list):
            episode = episode[0] if episode else None
        if episode is None:
            return None
        try:
            return f"S{int(season):02d}E{int(episode):02d}"
        except (TypeError, ValueError):
            return None


    def destination_for(source, source_root, target_root):
        rel = source.relative_to(source_root)
        info = guessit(str(rel))
        title = clean_name(info.get("title") or source.parent.name)
        media_type = info.get("type")

        season = episode_number(info.get("season"))
        episode = episode_number(info.get("episode"))
        tag = format_episode_tag(season, episode)

        if media_type == "episode" or tag is not None:
            show_name = clean_name(f"{title}{year_suffix(info)}")
            if season is None:
                season_dir = "Season 01"
            else:
                try:
                    season_dir = f"Season {int(season):02d}"
                except (TypeError, ValueError):
                    season_dir = "Season 01"
            tag = tag or f"EP{rel_hash(source)}"
            filename = clean_name(f"{title} {tag}") + source.suffix.lower()
            return target_root / "shows" / show_name / season_dir / filename

        if media_type == "movie" or info.get("year"):
            movie_name = clean_name(f"{title}{year_suffix(info)}")
            filename = movie_name + source.suffix.lower()
            return target_root / "movies" / movie_name / filename

        fallback_parent = clean_name(rel.parent.as_posix().replace("/", " - "))
        filename = clean_name(source.stem) + source.suffix.lower()
        return target_root / "unsorted" / fallback_parent / filename


    def same_file(left, right):
        try:
            return os.path.samefile(left, right)
        except OSError:
            return False


    def unique_target(target, source):
        if not target.exists() or same_file(source, target):
            return target
        suffix = rel_hash(source)
        return target.with_name(f"{target.stem} - {suffix}{target.suffix}")


    def load_manifest(path):
        if not path.exists():
            return {}
        try:
            with path.open("r", encoding="utf-8") as handle:
                data = json.load(handle)
            return data if isinstance(data, dict) else {}
        except (OSError, json.JSONDecodeError):
            return {}


    def save_manifest(path, manifest):
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        with tmp.open("w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(tmp, path)


    def remove_empty_dirs(path, stop):
        current = path
        while current != stop and stop in current.parents:
            try:
                current.rmdir()
            except OSError:
                break
            current = current.parent


    def link_source(source, target, target_root):
        target.parent.mkdir(parents=True, exist_ok=True)
        current = target.parent
        while current == target_root or target_root in current.parents:
            if current.exists():
                try:
                    os.chmod(current, 0o775)
                except OSError:
                    pass
            if current == target_root:
                break
            current = current.parent
        if target.exists():
            if same_file(source, target):
                return
            target.unlink()
        os.link(source, target)
        os.chmod(target, 0o664)


    def reconcile(source_root, target_root, manifest_path):
        source_root = source_root.resolve()
        target_root.mkdir(parents=True, exist_ok=True)
        manifest = load_manifest(manifest_path)
        active_sources = set()
        new_manifest = {}

        for source in media_files(source_root):
            try:
                source_key = str(source.resolve())
                base_target = destination_for(source, source_root, target_root)
                previous = manifest.get(source_key) if isinstance(manifest.get(source_key), dict) else {}
                old_target = previous.get("target")
                if old_target:
                    old_path = Path(old_target)
                    if old_path.exists() and not same_file(source, old_path):
                        old_path.unlink()
                        remove_empty_dirs(old_path.parent, target_root)

                target = unique_target(base_target, source)
                active_sources.add(source_key)

                if old_target and old_target != str(target):
                    old_path = Path(old_target)
                    if old_path.exists() and not same_file(source, old_path):
                        old_path.unlink()
                        remove_empty_dirs(old_path.parent, target_root)

                link_source(source, target, target_root)
                stat = source.stat()
                new_manifest[source_key] = {
                    "target": str(target),
                    "size": stat.st_size,
                    "mtime": stat.st_mtime,
                }
            except PermissionError as err:
                print(f"permission denied: {source}: {err}", file=sys.stderr)
            except OSError as err:
                print(f"failed to link {source}: {err}", file=sys.stderr)

        for source_key, entry in manifest.items():
            if source_key in active_sources or not isinstance(entry, dict):
                continue
            target = Path(entry.get("target", ""))
            if target.exists():
                try:
                    target.unlink()
                    remove_empty_dirs(target.parent, target_root)
                except OSError as err:
                    print(f"failed to remove stale target {target}: {err}", file=sys.stderr)

        save_manifest(manifest_path, new_manifest)


    class ChangeHandler(FileSystemEventHandler):
        def __init__(self):
            self.dirty = True

        def on_any_event(self, event):
            self.dirty = True


    def run_once(args):
        reconcile(args.source, args.target, args.manifest)


    def run_watch(args):
        handler = ChangeHandler()
        observer = Observer()
        observer.schedule(handler, str(args.source), recursive=True)
        observer.start()

        stopping = False

        def stop(_signum, _frame):
            nonlocal stopping
            stopping = True
            observer.stop()

        signal.signal(signal.SIGINT, stop)
        signal.signal(signal.SIGTERM, stop)

        try:
            while not stopping:
                if handler.dirty:
                    handler.dirty = False
                    reconcile(args.source, args.target, args.manifest)
                time.sleep(args.interval)
        finally:
            observer.stop()
            observer.join()


    def main():
        parser = argparse.ArgumentParser()
        parser.add_argument("--source", type=Path, default=Path("/earth/transmission"))
        parser.add_argument("--target", type=Path, default=Path("/earth/jellyfin"))
        parser.add_argument(
            "--manifest",
            type=Path,
            default=Path("/var/lib/jellyfin-organizer/manifest.json"),
        )
        parser.add_argument("--interval", type=float, default=20)
        parser.add_argument("--watch", action="store_true")
        args = parser.parse_args()

        if args.watch:
            run_watch(args)
        else:
            run_once(args)


    if __name__ == "__main__":
        main()
  '';

  jellyfinOrganizerTool = pkgs.writeShellApplication {
    name = "jellyfin-organizer";
    runtimeInputs = [jellyfinOrganizerPython];
    text = ''
      exec ${jellyfinOrganizerPython}/bin/python ${jellyfinOrganizer} "$@"
    '';
  };
in {
  services.jellyfin = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-ffmpeg
    jellyfinOrganizerTool
  ];

  users.groups.media.members = ["jellyfin"];

  systemd.tmpfiles.rules = [
    "d /earth/transmission 0775 transmission media - -"
    "d /earth/jellyfin 0775 jellyfin media - -"
    "d /earth/jellyfin/movies 0775 jellyfin media - -"
    "d /earth/jellyfin/shows 0775 jellyfin media - -"
    "d /earth/jellyfin/unsorted 0775 jellyfin media - -"
    "d /var/lib/jellyfin-organizer 0750 root media - -"
  ];

  systemd.services.jellyfin-organizer = {
    description = "Build clean Jellyfin hardlink library from Transmission downloads";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target" "transmission.service"];
    path = [
      pkgs.coreutils
      jellyfinOrganizerTool
    ];
    serviceConfig = {
      Type = "simple";
      User = "root";
      Group = "media";
      ExecStart = "${jellyfinOrganizerTool}/bin/jellyfin-organizer --watch";
      Restart = "always";
      RestartSec = "10s";
      ReadWritePaths = [
        "/earth/jellyfin"
        "/var/lib/jellyfin-organizer"
      ];
      ReadOnlyPaths = ["/earth/transmission"];
    };
  };

  systemd.services.jellyfin-organizer-scan = {
    description = "Reconcile clean Jellyfin hardlink library from Transmission downloads";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "media";
      ExecStart = "${jellyfinOrganizerTool}/bin/jellyfin-organizer";
      ReadWritePaths = [
        "/earth/jellyfin"
        "/var/lib/jellyfin-organizer"
      ];
      ReadOnlyPaths = ["/earth/transmission"];
    };
  };

  systemd.timers.jellyfin-organizer-scan = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "15m";
      Unit = "jellyfin-organizer-scan.service";
    };
  };
}
