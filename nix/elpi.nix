# Elpi 4.1.1, for a nixpkgs whose elpi is older (as nixpkgs-unstable on
# 2026-11-26): the same as nixpkgs master's, which adds only the version and
# findlib (used by the library elpi.dynload, which loads plugins)
{
  elpi,
  fetchurl,
  findlib,
  ocaml,
}:

elpi.overrideAttrs (old: rec {
  version = "4.1.1";
  name = "ocaml${ocaml.version}-elpi-${version}";
  src = fetchurl {
    url = "https://github.com/LPCIC/elpi/releases/download/v${version}/elpi-${version}.tbz";
    hash = "sha256-B8200zPmJ+V2RO5F5D7fqkogHSHvr9iSLo5eDUZJ+2g=";
  };
  propagatedBuildInputs = old.propagatedBuildInputs ++ [ findlib ];
})
