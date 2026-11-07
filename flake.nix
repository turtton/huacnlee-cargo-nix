{
  description = "Nix packages for the huacnlee Cargo fork";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      sources = (builtins.fromJSON (builtins.readFile ./hashes.json)).sources;
      forAllSystems = nixpkgs.lib.genAttrs (builtins.attrNames sources);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          cargo-huacnlee = pkgs.callPackage ./package.nix { };
          default = cargo-huacnlee;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/cargo";
          meta.description = "Run the huacnlee Cargo fork";
        };
      });

      overlays.default = final: _prev: {
        cargo-huacnlee = final.callPackage ./package.nix { };
      };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          package = self.packages.${system}.default;
        in
        {
          inherit package;
          smoke = pkgs.callPackage ./checks.nix { cargo-huacnlee = package; };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
