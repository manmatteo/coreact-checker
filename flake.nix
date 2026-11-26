{
  description = "ELPI checker for coreact-workbench theories";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
      # Elpi >= 4.1 and the packages built from its sources: nixpkgs' ones
      # once it has them, else the ones of ./nix
      ocamlPackagesOf = pkgs: pkgs.ocamlPackages.overrideScope (self: super: {
        elpi =
          if nixpkgs.lib.versionAtLeast super.elpi.version "4.1" then super.elpi
          else self.callPackage ./nix/elpi.nix { inherit (super) elpi; };
        elpi-lsp = super.elpi-lsp or (self.callPackage ./nix/elpi-lsp.nix { });
        ppx_elpi = super.ppx_elpi or (self.callPackage ./nix/ppx_elpi.nix { });
        elpi-json = super.elpi-json or (self.callPackage ./nix/elpi-json.nix { });
      });
    in {
      packages = forAll (pkgs:
        let ocamlPackages = ocamlPackagesOf pkgs; in rec {
          inherit (ocamlPackages) elpi elpi-lsp elpi-json;
          default = elpi-lsp;
        });

      devShells = forAll (pkgs:
        let ocamlPackages = ocamlPackagesOf pkgs; in {
          default = pkgs.mkShellNoCC {
            packages = with ocamlPackages; [ elpi elpi-lsp findlib pkgs.git ];
            # the hook of findlib puts these on OCAMLPATH, where elpi finds the
            # plugin of accumulate "+elpi-json" (and elpi-lsp its stub)
            buildInputs = [ ocamlPackages.elpi-json ];
          };
        });
    };
}
