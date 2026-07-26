{
  description = "NIO e2e test flake — a uniquely-hashed, non-cached derivation to exercise delegated remote builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # disko provides the declarative disk-partitioning module used by the
    # `nio-target` nixos-anywhere install config below. It follows the same
    # nixpkgs pin so there is a single nixpkgs revision across the flake.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, disko }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      # A trivial package whose source text embeds a unique marker, so its store
      # path is not present in any public cache and building it forces a real
      # build (on the NixBuilder, when one is referenced).
      packages = forAll (pkgs: {
        default = pkgs.writeShellScriptBin "nio-e2e-app" ''
          echo "NIO delegated remote-build e2e marker: uniq-20260707-a1"
        '';
      });

      # nixos-anywhere install target for the NIO operator e2e stand.
      #
      # This is the aarch64 NixOS system installed onto a throwaway Lima vz VM
      # via nixos-anywhere. disko partitions /dev/vda (ESP + ext4 root) and
      # configuration.nix pins a STATIC cluster-facing IP (192.168.105.240 on
      # enp0s2, the shared vmnet NIC) so the target's address is stable across
      # kexec/reboot — see nixos/configuration.nix for the full rationale. root
      # SSH access is authorized via nixos/authorized_keys, a committed
      # placeholder the operator overrides per-run through nixos-anywhere
      # `additionalFiles`.
      nixosConfigurations.nio-target = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          ./nixos/disk-config.nix
          ./nixos/configuration.nix
        ];
      };
    };
}
