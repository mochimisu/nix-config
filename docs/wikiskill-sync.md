# Wikiskill sync

Blackmoon and Gaia now use [direct Google Drive sync](wikiskill-drive.md) for wiki
content and plugin source. That page covers setup, credentials, recovery and conflicts.

`wikiskill-sync.nix` retains paused declarations for their former `wikiskill` and
`wikiskill-plugin` Syncthing folders so a rebuild cannot resume the old transport.
Obsidian continues to use its existing Syncthing configuration in `obsidian-sync.nix`.

Other hosts receive no Wikiskill folders or skill setup until Drive is explicitly
enabled and its credentials and initial baseline are provisioned. Never run both
content transports on the same replica.
