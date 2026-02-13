{
  ...
}: {
  # Pin CPU to performance governor for lower frametime variance during gaming.
  powerManagement.cpuFreqGovernor = "performance";

  # Use sched_ext with lavd policy for gaming-oriented scheduling behavior.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  # Prefer "none" for NVMe and "kyber" for non-rotational SATA/virt disks.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
    ACTION=="add", SUBSYSTEM=="block", KERNEL=="vd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
  '';
}
