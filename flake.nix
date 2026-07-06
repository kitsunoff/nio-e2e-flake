{
  description = "NIO e2e test flake — a uniquely-hashed, non-cached derivation to exercise delegated remote builds";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
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
    };
}
