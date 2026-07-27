{
  description = "NIO e2e fixture: a nixcluster downstream flake defining ONE incus cluster (no members — NIO injects them at converge time)";

  inputs = {
    # Pinned to nixcluster@master (20de2a6...) per the integration plan. Bump
    # deliberately, not via floating `master`, so this fixture's behavior is
    # reproducible independent of upstream nixcluster churn.
    nixcluster.url = "github:kitsunoff/nixcluster/99d432b31ec0163b0f9d56d78972976def6b39d1";

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
