# Retired Wikiskill Drive sync

Wikimem replaces filesystem Wikiskill as canonical memory. The Drive sync implementation, Nix service/timer, and encrypted grant were removed on 2026-10-03 after the functionality audit described in [Wikimem](wikimem.md#legacy-retirement-audit-2026-10-03).

Existing Drive files, local wiki/plugin trees, OAuth refresh state, and ingestion receipts are retained as archives. They are not synchronized into Wikimem. Keep attachments and raw sources until a separate migration accounts for them. Do not restart bisync or resync these archives as a memory transport.

Obsidian continues to use Syncthing. Paused legacy wiki folder declarations remain solely to prevent old folders from resuming on clients that preserve undeclared Syncthing folders.
