# The plugin of Elpi for Yojson: accumulate "+elpi-json" in a program. elpi
# finds it with findlib (OCAMLPATH), elpi-lsp reads its stub there instead
{
  buildDunePackage,
  elpi,
  ppx_deriving,
  ppx_elpi,
  yojson,
}:

buildDunePackage {
  pname = "elpi-json";
  inherit (elpi) version src;

  minimalOCamlVersion = "4.14";

  buildInputs = [
    ppx_deriving
    ppx_elpi
  ];

  propagatedBuildInputs = [
    elpi
    yojson
  ];

  # Only the test that links the plugin: dune runtest also runs rules of the
  # package elpi (which need elpi_REPL.exe), and the test check_package sets
  # OCAMLPATH to _build/install alone, where findlib does not find elpi
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    dune build -p elpi-json elpi-json/test/test_json.output
    diff elpi-json/test/test_json.expected _build/default/elpi-json/test/test_json.output
    runHook postCheck
  '';

  meta = elpi.meta // {
    description = "Yojson bindings for Elpi, as a plugin";
  };
}
