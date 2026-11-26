{
  buildDunePackage,
  elpi,
  ppxlib,
  re,
}:

buildDunePackage {
  pname = "ppx_elpi";
  inherit (elpi) version src;

  minimalOCamlVersion = "4.13";

  propagatedBuildInputs = [
    elpi
    ppxlib
    re
  ];

  meta = elpi.meta // {
    description = "[@@deriving elpi], Elpi's conversions for OCaml data types";
  };
}
