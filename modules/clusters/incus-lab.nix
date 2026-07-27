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
        clusterModules.incus
      ];

      # NOTE: sops is intentionally NOT enabled for this fixture. The Incus
      # cluster victory path needs no cluster secrets, and the sops.gen converge
      # preStep (which decrypts committed secrets to merge keys) is out of scope
      # here. ageKeyRef on the CR is harmless/unused. Re-add clusterModules.sops
      # + sops.enable if a scenario needs real secrets.

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
      # Incus daemon (clustering enabled above).
      defaultNixosConfiguration = inputs.nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          inputs.disko.nixosModules.disko
          ../../nixos/disk-config.nix
          ../../nixos/configuration.nix
        ];
      };
    };
}
