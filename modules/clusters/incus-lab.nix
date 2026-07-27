# Cluster-level definition for the "incus-lab" fixture cluster that NIO's
# NixCluster CR points at. NO node files ship with this repo (see
# modules/nodes/ — intentionally absent): NIO injects members as pure JSON
# data (install.ip only) at converge time, and every member falls back to
# `defaultNixosConfiguration` below (lib/resolveMemberBase.nix in nixcluster).
{ ... }:
{
  nixcluster.incus-lab =
    { clusterModules, inputs, ... }:
    {
      imports = [
        clusterModules.sops
        clusterModules.incus
      ];

      # sops-nix wiring: age key delivered out-of-band via
      # `nixclusterctl incus-lab install <member> --age-key-file ...`
      # (--extra-files stages it at /etc/age/key.txt on the target, outside
      # the nix store — see cluster-modules/sops.nix upstream). This sets
      # `sops.defaultSopsFile`/`sops.age.keyFile` on every member.
      sops.enable = true;

      # Cluster-level Incus extension: adds the Incus NixOS module (option
      # declarations + preseed/reconcile machinery) to every member. Actually
      # turning the daemon on per-node happens in nixos/configuration.nix
      # (`incus.enable = true;`), since NIO-injected members carry no patches
      # of their own beyond install.ip.
      incus.enable = true;

      # Multi-node clustering: the members form ONE Incus cluster. bootstrapMember
      # is left to its default (the first member sorted by name), which for NIO's
      # injected members is `nio-c1`. converge's incus.cluster-join step mints a
      # join token on the bootstrap and joins the rest. Keyed at cluster level so
      # NIO's data-only members (install.ip only) all participate.
      incus.cluster.enable = true;

      # Every member (including NIO-injected data-only ones) inherits this
      # base: disko (fresh-disk install via nixos-anywhere) + sshd/root key +
      # sops-nix + Incus daemon. See nixos/configuration.nix for the
      # incus-clustering TODO.
      defaultNixosConfiguration = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops
          ../../nixos/disk-config.nix
          ../../nixos/configuration.nix
        ];
      };
    };
}
