{
  lib,
  buildDunePackage,
  elpi,
  ppx_optcomp,
  sel,
  lsp,
  jsonrpc,
  yojson,
}:

buildDunePackage {
  pname = "elpi-lsp";
  inherit (elpi) version src;

  minimalOCamlVersion = "4.14";

  buildInputs = [
    elpi
    ppx_optcomp
    sel
    lsp
    jsonrpc
    yojson
  ];

  # The tests of the server are attached to the alias runtest-lsp, not runtest
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    dune build -p elpi-lsp ''${enableParallelBuilding:+-j $NIX_BUILD_CORES} @lsp/test/runtest-lsp
    runHook postCheck
  '';

  meta = elpi.meta // {
    description = "Language server for Elpi";
    mainProgram = "elpi-lsp";
  };
}
