# Preserve Comet's SD-card path and existing script name.
import ../../home/mpv-browser.nix {
  directory = "/run/media/steamos/USD00";
  fallback = "/run/media/steamos";
  scriptName = "comet-browser";
  unavailableMessage = "SD card is not mounted. Browsing mount directory.";
}
