## Windows 11 VM (VFIO GPU passthrough) on `gaia`

This host module creates a libvirt VM definition and binds your passthrough GPU to `vfio-pci`.

### 1) Find your GPU IDs + PCI addresses

Run:

`lspci -nn | rg -i "vga|3d|audio"`

You need:
- `virtualisation.win11Vfio.gpuDeviceIds`: vendor:device IDs like `10de:2684` (GPU) and `10de:22ba` (HDMI/DP audio).
- `virtualisation.win11Vfio.gpuDevices`: full PCI addresses like `0000:0a:00.0` and `0000:0a:00.1`.

### 2) Put ISO files where libvirt can read them

- Windows 11 ISO: `/var/lib/libvirt/iso/Win11.iso`
- VirtIO drivers ISO: `/var/lib/libvirt/iso/virtio-win.iso`

On `gaia`, the defaults are set to:

- Windows 11 ISO: `/earth/libvirt/iso/Win11.iso`
- VirtIO drivers ISO: `/earth/libvirt/iso/virtio-win.iso`

Override `virtualisation.win11Vfio.winIsoPath` / `virtualisation.win11Vfio.virtioIsoPath` if you prefer.

### 3) Enable the module

Edit `machines/gaia/configuration.nix` and set:
- `virtualisation.win11Vfio.enable = true;`
- `virtualisation.win11Vfio.gpuDeviceIds = [ ... ];`
- `virtualisation.win11Vfio.gpuDevices = [ ... ];`

Rebuild the host. The module will:
- enable `libvirtd` with `OVMF` + `swtpm` (TPM 2.0)
- create the disk image at `virtualisation.win11Vfio.diskPath` (default `.../win11.qcow2`)
- `virsh define` the VM domain at boot

### 4) Install Windows

Use `virt-manager` (locally or via SSH X-forwarding) or `virsh` + `virt-viewer` to start the VM and run installation.

During setup, load storage/network drivers from the VirtIO ISO when Windows asks for drivers.

### Notes

- You must enable IOMMU in BIOS/UEFI.
- If your GPU is the host display GPU, binding it to VFIO will black-screen the host console once the driver detaches.
- Windows 11 checks for TPM 2.0 + Secure Boot; this VM includes a virtual TPM but does not enable Secure Boot.
- If you use Parsec/Moonlight and hit capture/encoder errors, consider disabling the SPICE/QXL console by setting `virtualisation.win11Vfio.spice.enable = false;` and re-defining the domain.
- After Windows is installed, set `virtualisation.win11Vfio.attachInstallMedia = false;` to remove the ISO drives from the VM.
