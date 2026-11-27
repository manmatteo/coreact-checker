{
  description = "A proof checker in Elpi for the archives of coreact-workbench";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
      # Elpi >= 4.1 and the packages built from its sources: nixpkgs' ones
      # once it has them, else the ones of ./nix
      ocamlPackagesOf = pkgs: pkgs.ocamlPackages.overrideScope (final: prev: {
        elpi =
          if nixpkgs.lib.versionAtLeast prev.elpi.version "4.1" then prev.elpi
          else final.callPackage ./nix/elpi.nix { inherit (prev) elpi; };
        elpi-lsp = prev.elpi-lsp or (final.callPackage ./nix/elpi-lsp.nix { });
        ppx_elpi = prev.ppx_elpi or (final.callPackage ./nix/ppx_elpi.nix { });
        elpi-json = prev.elpi-json or (final.callPackage ./nix/elpi-json.nix { });
        # Elpi in a browser, with elpi-json
        elpi-web = final.callPackage ./nix/elpi-web.nix { };
      });
    in {
      packages = forAll (pkgs:
        let ocamlPackages = ocamlPackagesOf pkgs; in rec {
          inherit (ocamlPackages) elpi elpi-lsp elpi-json elpi-web;
          default = elpi-lsp;
          # the page, as GitHub Pages publishes it, with what it loads: Elpi on
          # the web, the checker (files.json: the texts of elpi/ and of
          # elpi-json, by the paths that accumulate reads) and the example
          site = pkgs.runCommand "coreact-checker-site" { nativeBuildInputs = [ pkgs.jq ]; } ''
            mkdir $out
            cp ${elpi-web}/elpi-api.js ${elpi-web}/web_api.bc.js $out/
            cp ${./web/index.html} $out/index.html
            cp ${./tests/joy_of_cats.hrx} $out/joy_of_cats.hrx
            {
              for f in ${./elpi}/*.elpi; do
                jq -Rs --arg p "/elpi/$(basename $f)" '{ ($p): . }' $f
              done
              for f in ${elpi-web}/packages/elpi-json/*; do
                jq -Rs --arg p "/packages/elpi-json/$(basename $f)" '{ ($p): . }' $f
              done
            } | jq -s add > $out/files.json
          '';
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

      # the tests of tests/; the example checks, and a broken copy does not
      checks = forAll (pkgs:
        let ocamlPackages = ocamlPackagesOf pkgs; in {
          default = pkgs.runCommand "coreact-checker-tests" {
            nativeBuildInputs = with ocamlPackages; [ elpi findlib ];
            buildInputs = [ ocamlPackages.elpi-json ];
          } ''
            cd ${./.}
            elpi -test tests/mono.elpi
            elpi -test tests/neg.elpi
            elpi -exec check_json elpi/from_json.elpi -- tests/joy_of_cats.hrx
            sed 's/exact isMono_4\./exact isMono_2./' tests/joy_of_cats.hrx > $TMPDIR/broken.hrx
            if elpi -exec check_json elpi/from_json.elpi -- $TMPDIR/broken.hrx cut; then exit 1; fi
            touch $out
          '';
        });
    };
}
