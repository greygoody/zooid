{
  description = "Nix package and NixOS module for Zooid";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          zooid = pkgs.callPackage ./nix/package.nix { };
          default = zooid;
        }
      );

      nixosModules = rec {
        zooid =
          { pkgs, lib, ... }:
          {
            imports = [ ./nix/module.nix ];
            services.zooid.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.zooid;
          };
        default = zooid;
      };

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./nix/checks.nix {
          inherit pkgs;
          package = self.packages.${system}.zooid;
          module = self.nixosModules.zooid;
        }
      );
    };
}
