# Dashcam Viewer vehicle artwork

These local, stock-style vehicle cards were generated for Gaia's private Dashcam Viewer configuration on 2026-08-29 using OpenAI's built-in image-generation tool. They are not third-party stock photography.

- `boxster.webp`: black 2009 Porsche Boxster, dark studio treatment.
- `taycan.webp`: white Porsche Taycan 4S, shared by the current and legacy archives.
- `redbean.webp`: generic red Tesla passenger-car treatment; the archive does not currently declare an exact model or year.

`machines/gaia/blackvue-viewer.nix` installs these files and the matching JSON descriptors into the vehicle archive roots before `dashcam-viewer.service` starts.
