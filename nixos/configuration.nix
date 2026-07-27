# The default base NixOS config for EVERY member of the "incus-lab" cluster
# (modules/clusters/incus-lab.nix). Reused/adapted from the proven aarch64
# nixos-anywhere base on `feat/nixos-target-static-ip` (disko + sshd), minus
# the single-VM static-IP pin: that base hardcoded one address for the lone
# e2e "nio-target" VM, but `defaultNixosConfiguration` here is shared by every
# cluster member, so a single hardcoded address would collide across members.
# DHCP keeps every member's network config self-consistent regardless of how
# many real VMs the cluster ends up with.
{ config, lib, pkgs, nixcluster ? null, ... }:
let
  # NIO injects each member's cluster IP as `install.ip`; nixcluster surfaces it
  # to the member's NixOS eval via `_module.args.nixcluster.member`.
  memberIp =
    if nixcluster != null && nixcluster ? member
    then (nixcluster.member.install.ip or null)
    else null;
in
{
  # aarch64 target platform.
  nixpkgs.hostPlatform = "aarch64-linux";

  # Bootloader for vz/UEFI (Colima/Lima vz aarch64 guests expose efivars, so
  # systemd-boot can write boot entries).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  # Two-NIC layout of the Lima aarch64 test VMs (predictable names OFF so the
  # kernel probe order gives stable eth0/eth1):
  #   eth0 = Lima usermode NAT (gvisor) — carries internet egress + default
  #          route + DNS; keep it on DHCP.
  #   eth1 = socket_vmnet `shared` net (192.168.105.0/24) — pin it to the
  #          member's cluster IP (install.ip) so the node stays reachable at
  #          Machine.spec.host across the nixos-anywhere kexec (DHCP would
  #          reassign and break host == Machine.spec.host).
  networking.usePredictableInterfaceNames = false;
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.eth1.ipv4.addresses =
    lib.optionals (memberIp != null) [
      { address = memberIp; prefixLength = 24; }
    ];

  # Incus on NixOS requires nftables (its virtual-network/firewall integration
  # is unsupported on the legacy iptables backend — a hard assertion upstream).
  networking.nftables.enable = true;

  # Open the Incus HTTPS API port so cluster members can reach each other
  # (join + inter-member traffic). Without this the firewall drops incoming
  # 8443 and joiners time out connecting to the bootstrap ("dial tcp
  # <bootstrap>:8443: i/o timeout").
  networking.firewall.allowedTCPPorts = [ 8443 ];

  # SSH for install/apply + post-install verification. root is authorized via
  # a FILE so NIO overrides the key per-run: NixosConfiguration's
  # `additionalFiles` mechanism force-stages a replacement `authorized_keys`
  # into the flake checkout (see docs/design/nixosconfiguration-v1alpha2.md)
  # before `install`/`apply` runs — the same "cluster key mechanism" already
  # proven for NIO's NixosConfiguration tier-1.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./authorized_keys ];

  # No interactive console autologin.
  services.getty.autologinUser = null;

  # --- Incus ---------------------------------------------------------------
  # `incus.enable` here is the NixOS-level option contributed by nixcluster's
  # `clusterModules.incus` (module decls added to every member once
  # `nixcluster.incus-lab.incus.enable = true` — see modules/clusters). Set it
  # directly on the default base (rather than per-member) so every member —
  # including NIO-injected data-only ones carrying nothing but install.ip —
  # runs the Incus daemon.
  incus.enable = true;
  incus.storageBackend = "dir"; # test-friendly: no spare block device required.

  # Multi-node Incus clustering is enabled at the cluster level in
  # modules/clusters/incus-lab.nix (`incus.cluster.enable = true`), which makes
  # the first member the bootstrap node and joins the rest via converge's
  # incus.cluster-join step. This base only turns the daemon on; the
  # bootstrap-vs-joiner preseed split is decided by nixcluster's incus module.

  # sops-nix is intentionally not wired here (see modules/clusters/incus-lab.nix):
  # the Incus cluster victory path needs no cluster secrets.

  # nixpkgs is pinned to nixos-unstable via `nixcluster/nixpkgs`, which
  # currently tracks the 26.11 cycle.
  system.stateVersion = "26.11";
}
