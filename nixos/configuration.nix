# The default base NixOS config for EVERY member of the "incus-lab" cluster
# (modules/clusters/incus-lab.nix). Reused/adapted from the proven aarch64
# nixos-anywhere base on `feat/nixos-target-static-ip` (disko + sshd), minus
# the single-VM static-IP pin: that base hardcoded one address for the lone
# e2e "nio-target" VM, but `defaultNixosConfiguration` here is shared by every
# cluster member, so a single hardcoded address would collide across members.
# DHCP keeps every member's network config self-consistent regardless of how
# many real VMs the cluster ends up with.
{ config, lib, pkgs, ... }:
{
  # aarch64 target platform.
  nixpkgs.hostPlatform = "aarch64-linux";

  # Bootloader for vz/UEFI (Colima/Lima vz aarch64 guests expose efivars, so
  # systemd-boot can write boot entries).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  networking.useDHCP = lib.mkDefault true;

  # Incus on NixOS requires nftables (its virtual-network/firewall integration
  # is unsupported on the legacy iptables backend — a hard assertion upstream).
  networking.nftables.enable = true;

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

  # TODO(incus-clustering): set incus.cluster.enable/bootstrapMember once the
  # nixcluster incus module supports clustering. Today each member only gets a
  # standalone `incus admin init --preseed` (single-node daemon); there is no
  # multi-node `incus cluster enable`/join wiring in nixcluster yet — that is
  # a separate follow-up task.

  # --- sops-nix --------------------------------------------------------------
  # `sops.age.keyFile` (-> /etc/age/key.txt) is set by nixcluster's
  # `clusterModules.sops` (cluster-modules/sops.nix), added to every member
  # once `nixcluster.incus-lab.sops.enable = true`. That same module also sets
  # `sops.defaultSopsFile` — but to the plain string "secrets/incus-lab.yaml"
  # (its `secretsDir` option is documented as "relative to project root", i.e.
  # meant for the CLI's shell scripts, which run with cwd = repo root). Passed
  # straight through to sops-nix's NixOS option, a relative string fails
  # sops-nix's `absolute path` type check at eval time. `mkForce` here with a
  # real Nix path (resolved against this file's location, so it lands as an
  # absolute /nix/store/... path once the flake is copied into the store)
  # overrides that string with the committed encrypted file. Declares one
  # trivial secret purely to prove the sops-nix wiring evaluates/decrypts end
  # to end; nothing else in this fixture consumes it.
  sops.defaultSopsFile = lib.mkForce ../secrets/incus-lab.yaml;
  sops.secrets."example/greeting" = { };

  # nixpkgs is pinned to nixos-unstable via `nixcluster/nixpkgs`, which
  # currently tracks the 26.11 cycle.
  system.stateVersion = "26.11";
}
