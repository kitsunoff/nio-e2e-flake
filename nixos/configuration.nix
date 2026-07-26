{ pkgs, ... }:
{
  # aarch64 target platform.
  nixpkgs.hostPlatform = "aarch64-linux";

  networking.hostName = "nio-target";

  # Bootloader for vz/UEFI. nixos-anywhere on a vz UEFI guest exposes efivars,
  # so systemd-boot can write boot entries. Keep canTouchEfiVariables = true
  # (the default that works for vz UEFI); flip to false only if the install
  # fails writing efivars.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  # ---------------------------------------------------------------------------
  # Networking: STATIC cluster-facing IP.
  #
  # The Lima vz VM has two NICs:
  #   - enp0s1 = user/slirp NIC. Provides outbound internet (NAT) plus the
  #     default route and DNS via DHCP.
  #   - enp0s2 = the shared vmnet NIC. This is the interface reachable from the
  #     cluster / operator, so it gets a STATIC address.
  #
  # Why static: with DHCP on the shared NIC, the vmnet server was observed to
  # reassign the address mid-install (during the kexec/reboot cycle). A changed
  # address breaks nixos-anywhere's reconnect and desyncs the operator's
  # Machine.spec.host, which pins a fixed target IP. Pinning 192.168.105.240
  # keeps the cluster-facing IP stable across kexec and reboot.
  #
  # .240 must sit OUTSIDE the socket_vmnet DHCP pool so the DHCP server never
  # hands it to another guest — the stand is expected to cap the pool below .240.
  #
  # We do NOT set a defaultGateway on enp0s2: its gateway (192.168.105.1) has no
  # internet NAT. The slirp NIC's DHCP lease supplies the default route + DNS,
  # so outbound connectivity stays working.
  # ---------------------------------------------------------------------------
  networking.useDHCP = false;
  networking.interfaces.enp0s2.ipv4.addresses = [
    { address = "192.168.105.240"; prefixLength = 24; }
  ];
  # slirp NIC keeps DHCP so the box has outbound internet + a default route:
  networking.interfaces.enp0s1.useDHCP = true;

  # SSH for post-install verification. root is authorized via a FILE so the
  # operator can override the key per-run (inject its own authorized_keys via
  # nixos-anywhere `additionalFiles`).
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];

  # No interactive console autologin.
  services.getty.autologinUser = null;

  # e2e markers the operator asserts after install.
  environment.etc."nio-e2e-marker".text = "nio-e2e-installed\n";

  systemd.services.nio-e2e-marker = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
    };
  };

  # nixpkgs is pinned to nixos-unstable, which currently tracks the 26.11 cycle.
  system.stateVersion = "26.11";
}
