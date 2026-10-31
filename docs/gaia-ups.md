# Gaia USB UPS

`machines/gaia/ups.nix` configures NUT for the USB `075d:0300`
(`-BMS- Smart-Battery`) device using `usbhid-ups`. The exact retail model
has not been verified. NUT listens only on localhost; no firewall port opens.
The local monitor credential is generated at service startup under root-only
`/var/lib/nut-private`, outside the store and Git.

The primary monitor uses NUT's normal on-battery plus low-battery (`OB LB`)
shutdown policy. A brief on-battery event alone does not trigger shutdown.
Battery percentage, runtime and voltage overrides are intentionally absent:
this USB family has reported inaccurate telemetry. Verify the actual readings
before changing the low-battery policy.

At the end of a NUT-triggered shutdown, the NixOS module checks `/run/killpower`
and invokes the driver shutdown path. This configuration requests only
`shutdown.return`; it does not fall back to a stay-off command. NUT 2.8.4's
iDowell driver recognizes this USB ID and can synthesize `shutdown.return`
when the device exposes both delayed output-off and output-on commands.
Actual firmware behavior must still be tested.

## Activation and verification

From `/home/brandon/stuff/nix-config` on Gaia:

```sh
sudo nixos-rebuild switch --flake .#gaia
systemctl status nut-local-password upsd upsdrv upsmon
upsc gaia@127.0.0.1
upscmd -l gaia@127.0.0.1
journalctl -b -u upsdrv -u upsd -u upsmon --no-pager
```

The rebuild activates all pending configuration changes; review those first.
The `upscmd -l` command only lists supported commands. Expect `OL` while mains
is present, sensible battery charge, and `shutdown.return` in the command list.
Check the logs for successful monitor authentication and stable USB updates.
If telemetry is incorrect, investigate before treating protection as verified.

For automatic boot, set Gaia's ASUS UEFI **Advanced → APM Configuration →
Restore AC Power Loss → Power On**. Linux configuration cannot set or confirm
this firmware setting. Power must actually be removed from and restored to
the computer; a software halt with uninterrupted UPS output will stay off.

Arrange a supervised outage/shutdown test separately, including mains returning
during shutdown. Commands such as `upsmon -c fsd`, `upsdrvctl shutdown`, or
`upscmd ... shutdown.return` are disruptive and are not setup checks.

## Setup status (2026-10-30)

USB enumeration is confirmed. Gaia configuration evaluation and the full system
build passed; generated UPS configuration and credential unit were inspected. Activation,
live telemetry, low-battery behavior, output cycling and the BIOS setting need
verification. Setup's unprivileged session could not access the USB device for
NUT or activate the services because sudo requires a password.

## References

- [NUT monitor policy](https://networkupstools.org/docs/man/upsmon.conf.html)
- [USB HID driver](https://networkupstools.org/docs/man/usbhid-ups.html)
- [Matching USB family telemetry issue](https://github.com/networkupstools/nut/issues/3556)
