# coreact-checker

A proof checker, written in [Elpi](https://github.com/LPCIC/elpi), for the archives of
[coreact-workbench](https://github.com/amblafont/coreact-workbench): the `.hrx` file that its
*Save* button writes. It reads the rules of the archive and the Rocq proofs recorded with them, and
checks the proofs with a small kernel. Equalities are handled by one of two backends: `cut`
(union-find) or `part` (partitions). Rules without a proof are taken as axioms.

**In a browser:** https://manmatteo.github.io/coreact-checker/. Nothing to install, and the archive
stays on your machine.

**From the command line,** with Nix:

    nix develop -c elpi -exec check_json elpi/from_json.elpi -- my.hrx cut part

If a proof does not check, it names the first rule that fails.

## Layout

- `elpi/`: the checker. `from_json.elpi` reads an archive (with the elpi-json plugin), and
  `kernel.elpi` checks the proofs, with `eq_cut.elpi` or `eq_part.elpi` for equalities.
- `tests/`: `joy_of_cats.hrx`, results of *The Joy of Cats* (Adámek–Herrlich–Strecker) proved in
  the workbench, which is also the example of the page; `neg.elpi`, proofs that every backend must
  accept or reject; `mono.elpi`, a development written by hand.
- `web/index.html`: the page. `nix build .#site` builds it into `result/`, with Elpi compiled to
  WebAssembly and to JavaScript (`nix/elpi-web.nix`, Elpi's webrunner with elpi-json linked in);
  `python3 -m http.server -d result` serves it.
- `nix/`: Elpi 4.1 and elpi-json until nixpkgs has them, and elpi-lsp for editors.

`nix flake check` runs the tests. `.github/workflows/pages.yml` runs them too, checks the page in
a browser, and publishes it from `main`.
