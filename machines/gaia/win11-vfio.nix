{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.virtualisation.win11Vfio;

  ovmfDir = "${pkgs.OVMF.fd}/FV";
  ovmfCode = "${ovmfDir}/OVMF_CODE.fd";
  ovmfVars = "${ovmfDir}/OVMF_VARS.fd";

  installMediaXml =
    if cfg.attachInstallMedia
    then ''
      <disk type='file' device='cdrom'>
        <driver name='qemu' type='raw'/>
        <source file='${cfg.winIsoPath}'/>
        <target dev='sda' bus='sata'/>
        <readonly/>
      </disk>

      <disk type='file' device='cdrom'>
        <driver name='qemu' type='raw'/>
        <source file='${cfg.virtioIsoPath}'/>
        <target dev='sdb' bus='sata'/>
        <readonly/>
      </disk>
    ''
    else "";

  spiceXml =
    if cfg.spice.enable
    then ''
      <graphics type='spice' autoport='yes' listen='${cfg.spice.listenAddress}'>
        <listen type='address' address='${cfg.spice.listenAddress}'/>
      </graphics>
      <video>
        <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
      </video>
    ''
    else ''
      <video>
        <model type='none'/>
      </video>
    '';

  interfaceXml =
    if cfg.network.type == "bridge"
    then ''
      <interface type='bridge'>
        <source bridge='${cfg.network.bridgeName}'/>
        <model type='virtio'/>
      </interface>
    ''
    else if cfg.network.type == "direct"
    then ''
      <interface type='direct'>
        <source dev='${cfg.network.directDev}' mode='${cfg.network.directMode}'/>
        <model type='virtio'/>
      </interface>
    ''
    else ''
      <interface type='network'>
        <source network='${cfg.network.networkName}'/>
        <model type='virtio'/>
      </interface>
    '';

  hostAccessInterfaceXml = lib.optionalString cfg.hostAccess.enable ''
    <interface type='network'>
      <source network='${cfg.hostAccess.networkName}'/>
      <model type='virtio'/>
    </interface>
  '';

  defaultNetworkXml = pkgs.writeText "libvirt-default-network.xml" ''
    <network>
      <name>default</name>
      <forward mode='nat'/>
      <bridge name='virbr0' stp='on' delay='0'/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
        </dhcp>
      </ip>
    </network>
  '';

  ensureDefaultNetwork = pkgs.writeShellScript "ensure-libvirt-default-network" ''
    set -euo pipefail

    uri="qemu:///system"

    if ! ${pkgs.libvirt}/bin/virsh -c "$uri" net-info default >/dev/null 2>&1; then
      ${pkgs.libvirt}/bin/virsh -c "$uri" net-define "${defaultNetworkXml}" >/dev/null
      ${pkgs.libvirt}/bin/virsh -c "$uri" net-autostart default >/dev/null || true
    fi

    ${pkgs.libvirt}/bin/virsh -c "$uri" net-autostart default >/dev/null || true
    ${pkgs.libvirt}/bin/virsh -c "$uri" net-start default >/dev/null 2>&1 || true
  '';

  pciAddrToHostdev = addr: let
    m = builtins.match "([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\\.([0-7])" addr;
  in
    if m == null
    then throw "virtualisation.win11Vfio.gpuDevices must look like 0000:0a:00.0 (got: ${addr})"
    else ''
      <hostdev mode='subsystem' type='pci' managed='yes'>
        <source>
          <address domain='0x${builtins.elemAt m 0}' bus='0x${builtins.elemAt m 1}' slot='0x${builtins.elemAt m 2}' function='0x${builtins.elemAt m 3}'/>
        </source>
      </hostdev>
    '';

  hostdevsXml = lib.concatStringsSep "\n" (map pciAddrToHostdev cfg.gpuDevices);

  win11DomainXml = pkgs.writeText "win11-${cfg.name}.xml" ''
    <domain type='kvm'>
      <name>${cfg.name}</name>
      <memory unit='MiB'>${toString cfg.memoryMiB}</memory>
      <currentMemory unit='MiB'>${toString cfg.memoryMiB}</currentMemory>
      <vcpu placement='static'>${toString cfg.vcpus}</vcpu>
      <os>
        <type arch='x86_64' machine='q35'>hvm</type>
        <loader readonly='yes' type='pflash'>${ovmfCode}</loader>
        <nvram template='${ovmfVars}'>/var/lib/libvirt/qemu/nvram/${cfg.name}_VARS.fd</nvram>
        <boot dev='cdrom'/>
        <boot dev='hd'/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <hyperv mode='custom'>
          <relaxed state='on'/>
          <vapic state='on'/>
          <spinlocks state='on' retries='8191'/>
          <vpindex state='on'/>
          <runtime state='on'/>
          <synic state='on'/>
          <stimer state='on'/>
          <reset state='on'/>
          <vendor_id state='on' value='NixOSKVM'/>
        </hyperv>
        <kvm>
          <hidden state='on'/>
        </kvm>
      </features>
      <cpu mode='host-passthrough' check='none' migratable='on'>
        <feature policy='disable' name='hypervisor'/>
      </cpu>
      <clock offset='localtime'>
        <timer name='hpet' present='no'/>
        <timer name='hypervclock' present='yes'/>
      </clock>
      <devices>
        <emulator>${pkgs.qemu_kvm}/bin/qemu-system-x86_64</emulator>

        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap'/>
          <source file='${cfg.diskPath}'/>
          <target dev='vda' bus='virtio'/>
        </disk>

        ${installMediaXml}

        <controller type='usb' model='qemu-xhci'/>
        <controller type='sata' index='0'/>
        <controller type='pci' model='pcie-root'/>

        ${interfaceXml}
        ${hostAccessInterfaceXml}

        <tpm model='tpm-crb'>
          <backend type='emulator' version='2.0'/>
        </tpm>

        ${hostdevsXml}

        ${spiceXml}
        <sound model='ich9'/>
        <input type='tablet' bus='usb'/>
        <input type='mouse' bus='ps2'/>
        <input type='keyboard' bus='ps2'/>
      </devices>
    </domain>
  '';

  defineWin11 = pkgs.writeShellScript "define-win11-${cfg.name}" ''
    set -euo pipefail

    uri="qemu:///system"
    name="${cfg.name}"
    xml="${win11DomainXml}"

    if [ "${toString cfg.attachInstallMedia}" = "1" ]; then
      if [ ! -r "${cfg.winIsoPath}" ]; then
        exit 0
      fi
      if [ ! -r "${cfg.virtioIsoPath}" ]; then
        exit 0
      fi
    fi

    if ${pkgs.libvirt}/bin/virsh -c "$uri" dominfo "$name" >/dev/null 2>&1; then
      state="$(${pkgs.libvirt}/bin/virsh -c "$uri" domstate "$name" | ${pkgs.coreutils}/bin/tr -d '\r')"
      if [ "$state" = "running" ]; then
        exit 0
      fi

      # Don't fail the host activation if a domain already exists (or libvirt
      # refuses to redefine it). If you need to apply a changed definition:
      #   virsh -c qemu:///system undefine --nvram "$name"
      #   systemctl start "win11-$name-define.service"
      ${pkgs.libvirt}/bin/virsh -c "$uri" define "$xml" >/dev/null 2>&1 || exit 0
      exit 0
    fi

    ${pkgs.libvirt}/bin/virsh -c "$uri" define "$xml" >/dev/null
  '';

  ensureDisk = pkgs.writeShellScript "ensure-win11-disk-${cfg.name}" ''
    set -euo pipefail

    img="${cfg.diskPath}"
    if [ -e "$img" ]; then
      exit 0
    fi

    ${pkgs.coreutils}/bin/install -d -m 0755 "$(${pkgs.coreutils}/bin/dirname "$img")"
    ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$img" "${toString cfg.diskSizeGiB}G" >/dev/null

    if ${pkgs.coreutils}/bin/id -u libvirt-qemu >/dev/null 2>&1; then
      ${pkgs.coreutils}/bin/chown libvirt-qemu:kvm "$img" || true
    fi
    ${pkgs.coreutils}/bin/chmod 0660 "$img"
  '';
in {
  options.virtualisation.win11Vfio = {
    enable = lib.mkEnableOption "Windows 11 VFIO VM (libvirt + GPU passthrough)";

    name = lib.mkOption {
      type = lib.types.str;
      default = "win11";
    };

    iommu = lib.mkOption {
      type = lib.types.enum ["intel" "amd" "both"];
      default = "both";
    };

    spice = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose a SPICE console (QXL). Disable for a pure GPU-passthrough (headless) VM.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "SPICE listen address (only used when spice.enable = true).";
      };
    };

    network = {
      type = lib.mkOption {
        type = lib.types.enum ["network" "bridge" "direct"];
        default = "network";
        description = "Use libvirt NAT network (network), a host bridge (bridge), or a macvtap-style direct interface (direct).";
      };

      networkName = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "libvirt network name (only used when network.type = \"network\").";
      };

      bridgeName = lib.mkOption {
        type = lib.types.str;
        default = "br0";
        description = "Host bridge interface name (only used when network.type = \"bridge\").";
      };

      directDev = lib.mkOption {
        type = lib.types.str;
        default = "enp5s0";
        description = "Host NIC device name (only used when network.type = \"direct\").";
      };

      directMode = lib.mkOption {
        type = lib.types.enum ["bridge" "vepa" "private" "passthrough"];
        default = "bridge";
        description = "Direct interface mode (only used when network.type = \"direct\").";
      };
    };

    hostAccess = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Add a second NIC on a libvirt network (default: 'default') so the VM can always reach the host (useful with macvtap/direct, where host<->guest traffic is blocked).";
      };

      networkName = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "libvirt network name for the host-access NIC.";
      };
    };

    gpuDeviceIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["10de:1b80" "10de:10f0"];
      description = "PCI vendor:device IDs to bind to vfio-pci (GPU + GPU audio, etc).";
    };

    gpuDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["0000:0a:00.0" "0000:0a:00.1"];
      description = "PCI addresses to attach to the VM as hostdev devices.";
    };

    diskPath = lib.mkOption {
      type = lib.types.str;
      default = "/earth/libvirt/images/win11.qcow2";
    };

    diskSizeGiB = lib.mkOption {
      type = lib.types.int;
      default = 200;
    };

    attachInstallMedia = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Attach Windows + VirtIO ISO drives (set false after install).";
    };

    memoryMiB = lib.mkOption {
      type = lib.types.int;
      default = 16384;
    };

    vcpus = lib.mkOption {
      type = lib.types.int;
      default = 8;
    };

    winIsoPath = lib.mkOption {
      type = lib.types.str;
      default = "/earth/libvirt/iso/Win11.iso";
    };

    virtioIsoPath = lib.mkOption {
      type = lib.types.str;
      default = "/earth/libvirt/iso/virtio-win.iso";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.pathExists ovmfCode && builtins.pathExists ovmfVars;
        message = "Could not find OVMF firmware images at ${ovmfCode} / ${ovmfVars}.";
      }
    ];

    warnings =
      (lib.optionals (cfg.gpuDeviceIds == []) [
        "virtualisation.win11Vfio: gpuDeviceIds is empty; vfio-pci binding will be skipped."
      ])
      ++ (lib.optionals (cfg.gpuDevices == []) [
        "virtualisation.win11Vfio: gpuDevices is empty; the VM will be defined without GPU passthrough (SPICE/QXL only)."
      ]);

    boot.kernelParams =
      (lib.optionals (cfg.iommu == "intel" || cfg.iommu == "both") ["intel_iommu=on"])
      ++ (lib.optionals (cfg.iommu == "amd" || cfg.iommu == "both") ["amd_iommu=on"])
      ++ ["iommu=pt"]
      ++ (lib.optionals (cfg.gpuDeviceIds != []) ["vfio-pci.ids=${lib.concatStringsSep "," cfg.gpuDeviceIds}"]);

    boot.initrd.kernelModules = lib.optionals (cfg.gpuDeviceIds != []) [
      "vfio"
      "vfio_pci"
      "vfio_iommu_type1"
    ];

    boot.blacklistedKernelModules = lib.optionals (cfg.gpuDeviceIds != []) [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
    ];

    boot.extraModprobeConfig = lib.mkAfter (lib.optionalString (cfg.gpuDeviceIds != []) ''
      options vfio-pci ids=${lib.concatStringsSep "," cfg.gpuDeviceIds} disable_vga=1
    '');

    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
      };
    };

    virtualisation.spiceUSBRedirection.enable = true;

    environment.systemPackages = with pkgs; [
      libvirt
      qemu
      swtpm
      pciutils
    ];

    networking.firewall.trustedInterfaces = lib.mkAfter (
      lib.optionals (
        (cfg.network.type == "network" && cfg.network.networkName == "default")
        || (cfg.hostAccess.enable && cfg.hostAccess.networkName == "default")
      ) ["virbr0"]
    );

    systemd.tmpfiles.rules = [
      "d ${builtins.dirOf cfg.winIsoPath} 0755 root root - -"
      "d ${builtins.dirOf cfg.virtioIsoPath} 0755 root root - -"
      "d ${builtins.dirOf cfg.diskPath} 0755 root root - -"
    ];

    users.users.brandon.extraGroups = [
      "kvm"
      "libvirtd"
    ];

    systemd.services.libvirt-default-network = lib.mkIf (
      (cfg.network.type == "network" && cfg.network.networkName == "default")
      || (cfg.hostAccess.enable && cfg.hostAccess.networkName == "default")
    ) {
      description = "Ensure libvirt 'default' network is defined and active";
      wantedBy = ["multi-user.target"];
      after = ["libvirtd.service"];
      requires = ["libvirtd.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ensureDefaultNetwork;
      };
    };

    systemd.services.libvirt-guests = {
      # Don't race /earth-backed disk availability.
      after = [ "earth.mount" ];
      requires = [ "earth.mount" ];
      # VFIO passthrough guests cannot be "suspended" with libvirt save.
      # Use shutdown semantics and avoid boot-time auto-start from libvirt-guests.
      environment = {
        ON_BOOT = lib.mkForce "ignore";
        ON_SHUTDOWN = lib.mkForce "shutdown";
        SHUTDOWN_TIMEOUT = lib.mkForce "45";
      };
    };

    systemd.services."win11-${cfg.name}-disk" = {
      description = "Create libvirt disk for ${cfg.name}";
      wantedBy = ["multi-user.target"];
      after = ["local-fs.target"];
      before = ["libvirtd.service"];
      unitConfig.RequiresMountsFor = ["/earth"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ensureDisk;
      };
    };

    systemd.services."win11-${cfg.name}-define" = {
      description = "Define libvirt domain for ${cfg.name}";
      wantedBy = ["multi-user.target"];
      after =
        ["local-fs.target" "libvirtd.service"]
        ++ (lib.optionals (cfg.network.type == "network" && cfg.network.networkName == "default") ["libvirt-default-network.service"]);
      requires =
        ["libvirtd.service"]
        ++ (lib.optionals (cfg.network.type == "network" && cfg.network.networkName == "default") ["libvirt-default-network.service"]);
      unitConfig.RequiresMountsFor = ["/earth"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = defineWin11;
      };
    };
  };
}
