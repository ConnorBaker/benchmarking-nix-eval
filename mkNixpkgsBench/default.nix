{
  jq,
  lib,
  stdenvNoCC,
  system,
  time,
  timeFormatJson,
  writers,
  writeTextDir,
}:
# The benchConfig attribute set
# TODO: Flags for common stuff like GC initial heap size, disabling GC, using Nix built without GC, etc.
benchConfig@{
  # Attribute path relative to expression at `filePath`
  # Example: `["closures" "smallContainer" "x86_64-linux"]`
  attrPath,

  # File path relative to nixpkgs root
  # Example: `nixos/release.nix`
  relativeFilePath,

  # Number of times to run the evaluation.
  numRuns,

  # Configuration relating to Nixpkgs.
  nixpkgsBenchConfig,

  # Configuration relating to Nix.
  nixBenchConfig,
}:
let
  nixpkgsFlake = nixpkgsBenchConfig.flake;
in
stdenvNoCC.mkDerivation {
  allowSubstitutes = false;
  preferLocalBuild = true;

  __structuredAttrs = true;
  strictDeps = true;

  name = "${nixBenchConfig.name}-${nixpkgsBenchConfig.name}-bench";

  # The .dev output is selected by default, which isn't what we want.
  nativeBuildInputs = [
    jq
    nixBenchConfig.nix.out
    time
  ];

  # NOTE: --file implies --impure.
  # NOTE: due to --impure we can use the nix-path setting to access nixpkgs which would otherwise be forbidden in
  # restricted eval.
  # NOTE: Still need to create the dummy stores since Nix will try to realize derivations even when provided with
  # the dummy store.
  # NOTE: eval-system and eval-store might be too new for some Nix versions.
  nixEvalArgs = [
    # "--print-build-logs"
    # "--show-trace"
    "--quiet"
    "--offline"
    "--system"
    system
    # "--eval-system"
    # system
    "--read-only"
    "--json"
    "--store"
    "dummy://"
    # "--eval-store"
    # "dummy://"
  ];

  # "NIX_CONF_DIR" is set manually and so is not included.
  nixDirs = [
    "NIX_DATA_DIR" # Overrides the location of the Nix static data directory (default prefix/share).
    "NIX_LOG_DIR" # Overrides the location of the Nix log directory (default prefix/var/log/nix).
    "NIX_STATE_DIR" # Overrides the location of the Nix state directory (default prefix/var/nix).
    "NIX_STORE_DIR" # Overrides the location of the Nix store directory (default prefix/store).
  ];

  env =
    {
      NIX_CONF_DIR = writeTextDir "nix.conf" ''
        allow-import-from-derivation = false
        eval-cache = false
        experimental-features = nix-command flakes
        fsync-metadata = false
        fsync-store-paths = false
        keep-build-log = false
        keep-derivations = false
        keep-env-derivations = false
        nix-path = nixpkgs=${nixpkgsFlake.outPath}
        pure-eval = true
        restrict-eval = true
        use-xdg-base-directories = true
      '';
      NIX_SHOW_STATS = "1";
    }
    # Here's a funny thing: it doesn't matter what this environment variable is set to -- as long as it is set,
    # no GC will occur.
    // lib.optionalAttrs nixBenchConfig.dontGC {
      GC_DONT_GC = "1";
    };

  evalFilePath = "${nixpkgsFlake.outPath}/${relativeFilePath}";
  evalAttrPath = lib.showAttrPath attrPath;

  inherit numRuns timeFormatJson;

  benchConfigJson = writers.writeJSON "benchConfig.json" benchConfig;

  buildCommandPath = ./build-command.bash;
}
