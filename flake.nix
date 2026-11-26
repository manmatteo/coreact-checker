{
  description = "ELPI checker for coreact-workbench theories";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
      # Use nixpkgs' elpi-lsp once it exists there, else build it from ./nix
      mkElpiLsp = pkgs:
        pkgs.ocamlPackages.elpi-lsp or (pkgs.ocamlPackages.callPackage ./nix/elpi-lsp.nix { });
    in {
      packages = forAll (pkgs: rec {
        elpi = pkgs.ocamlPackages.elpi;
        elpi-lsp = mkElpiLsp pkgs;
        default = elpi-lsp;
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [ pkgs.ocamlPackages.elpi (mkElpiLsp pkgs) pkgs.git ];
        };
      });
    };
}
