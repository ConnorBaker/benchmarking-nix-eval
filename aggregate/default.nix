# NOTE: This pattern prevents callPackage from automatically providing an argument
# to the function, while also ensuring the function is called with it.
{ jq, stdenvNoCC }:
{ constituents }:
stdenvNoCC.mkDerivation {
  allowSubstitutes = false;
  preferLocalBuild = true;

  __structuredAttrs = true;
  strictDeps = true;

  name = "aggregated";

  nativeBuildInputs = [ jq ];

  inherit constituents;

  buildCommand = ''
    for constituent in "''${constituents[@]}"; do
      cat "$constituent" >> aggregated.json
    done
    jq --sort-keys --slurp 'add' < "aggregated.json" > "$out"
  '';
}
