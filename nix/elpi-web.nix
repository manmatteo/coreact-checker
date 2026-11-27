# Elpi's API for JavaScript (webrunner/ of its sources, as in the npm package
# elpi-webrunner), with the plugin elpi-json linked in (./elpi-web.patch):
# elpi-api.js, which inlines the WebAssembly build, and web_api.bc.js, the
# JavaScript build it falls back to, served next to each other; and the files
# of elpi-json in packages/elpi-json, where accumulate "+elpi-json/utils"
# looks (as /packages/elpi-json/utils.elpi, for the fileReader)
{
  elpi,
  binaryen,
  js_of_ocaml,
  js_of_ocaml-compiler,
  wasm_of_ocaml-compiler,
  nodejs,
  ppxlib,
  yojson,
}:

elpi.overrideAttrs (old: {
  pname = "elpi-web";
  name = "elpi-web-${old.version}";
  outputs = [ "out" ];
  patches = (old.patches or [ ]) ++ [ ./elpi-web.patch ];

  nativeBuildInputs = old.nativeBuildInputs ++ [
    js_of_ocaml-compiler
    wasm_of_ocaml-compiler
    binaryen
    nodejs # webrunner/assemble.cjs
  ];
  # elpi-json and ppx_elpi are built from the same sources; nothing is
  # propagated, since the output is not an OCaml library
  buildInputs = old.buildInputs ++ old.propagatedBuildInputs ++ [
    js_of_ocaml
    ppxlib
    yojson
  ];
  propagatedBuildInputs = [ ];

  # the release profile, as make webrunner (the dev one is ten times bigger)
  buildPhase = ''
    runHook preBuild
    dune build --profile release webrunner/elpi-api.js webrunner/web_api.bc.js
    runHook postBuild
  '';
  doCheck = false;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/packages/elpi-json
    cp _build/default/webrunner/elpi-api.js _build/default/webrunner/web_api.bc.js \
      webrunner/elpi-api.d.ts $out/
    cp elpi-json/utils.elpi $out/packages/elpi-json/
    runHook postInstall
  '';
})
