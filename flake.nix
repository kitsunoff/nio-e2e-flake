{
  description = "NIO e2e fixture: a nixcluster downstream flake defining ONE incus cluster (no members — NIO injects them at converge time)";

  inputs = {
    # Pinned to nixcluster@master (9b9ee61...). Bump deliberately, not via a
    # floating `master`, so this fixture's behavior is reproducible independent
    # of upstream nixcluster churn.
    nixcluster.url = "github:kitsunoff/nixcluster/9b9ee61af438037ddff0b05e806282251c67b255";

    # Reuse nixcluster's locked inputs for a single consistent set (same
    # pattern as nixcluster's own downstream template).
    nixpkgs.follows = "nixcluster/nixpkgs";
    flake-parts.follows = "nixcluster/flake-parts";
    import-tree.follows = "nixcluster/import-tree";
    disko.follows = "nixcluster/disko";
    sops-nix.follows = "nixcluster/sops-nix";
  };

  outputs =
    inputs@{ flake-parts, import-tree, nixcluster, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Members are real (or throwaway-VM) aarch64 machines only.
      systems = [ "aarch64-linux" ];

      imports = [
        # Declarative `nixcluster.<cluster>` option -> clusterConfigurations.
        nixcluster.flakeModules.default
        # Auto-import everything under ./modules (clusters/clusterModules/nodes).
        (import-tree ./modules)
      ];
    };
}
