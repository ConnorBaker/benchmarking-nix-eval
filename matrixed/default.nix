{
  aggregate,
  benchmarks,
  lib,
  matrixed,
  mkNixpkgsBench,
  numRuns,
  system,
  releaseTools,
}:
let
  inherit (builtins)
    getFlake
    import
    ;

  inherit (lib.attrsets)
    attrNames
    attrValues
    cartesianProduct
    isDerivation
    mapAttrsRecursiveCond
    ;
  inherit (lib.lists) concatMap map;
  inherit (lib.trivial) throwIfNot;

  nixpkgsBenchConfigs =
    let
      # Generally the Nixpkgs revision shouldn't change, as we want to measure the same
      # Nixpkgs revision across all Nix revisions.
      rev = "feb59789efc219f624b66baf47e39be6fe07a552";
      flake = getFlake "github:NixOS/nixpkgs/${rev}";
      nixpkgsBenchConfig = {
        inherit flake;
        # Should be prefixed with `nixpkgs-`.
        name = "nixpkgs-${flake.shortRev}";
      };
    in
    [ nixpkgsBenchConfig ];

  nixBenchConfigs =
    let
      nixTagToRev = import ./nix-tag-to-rev.nix;
    in
    concatMap (
      tag:
      let
        rev = nixTagToRev.${tag};
        flake = getFlake "github:NixOS/nix/${rev}";
        default = {
          # flake doesn't necessarily have a `tag` attribute, but it does have rev.
          inherit tag flake;
          # Name for this config. Helpful when using different variants of Nix on the same tag.
          # Should be prefixed with `nix-`.
          name = "nix-${tag}";
          # Nix package to use.
          inherit (flake.packages.${system}) nix;
          # Allow runtime garbage collection.
          dontGC = false;
          # Use the BDWGC allocator.
          # NOTE: This field is for metadata purposes.
          useBDWGC = true;
        };
      in
      [
        # The standard Nix package.
        default
        # The same as above, but we disable runtime garbage collection.
        (
          default
          // {
            name = "nix-${tag}-no-gc";
            dontGC = true;
          }
        )
        # The Nix package built without GC entirely.
        # dontGC doesn't apply here, but we keep it set to true for consistency.
        (
          let
            inherit (flake.hydraJobs) buildNoGc;
            # There have been a number of ways hydraJobs has been structured.
            # We try to find the right one.
            nix = buildNoGc.nix-everything.${system} or buildNoGc.nix.${system} or buildNoGc.${system};
          in
          default
          // {
            name = "nix-${tag}-no-bdwgc";
            dontGC = true;
            useBDWGC = false;
            nix = throwIfNot (isDerivation nix) "nix must be a derivation" nix;
          }
        )
      ]
    ) (attrNames nixTagToRev);

  mkNixpkgsMatrix =
    let
      configs = cartesianProduct {
        nixpkgsBenchConfig = nixpkgsBenchConfigs;
        nixBenchConfig = nixBenchConfigs;
      };
    in
    # Partial benchmark configs
    {
      attrPath,
      relativeFilePath,
    }:
    map (
      { nixpkgsBenchConfig, nixBenchConfig }:
      mkNixpkgsBench {
        inherit
          attrPath
          relativeFilePath
          nixpkgsBenchConfig
          nixBenchConfig
          numRuns
          ;
      }
    ) configs;
in
{
  # An easy way to build all requisite Nix versions
  all-nix-packages = releaseTools.aggregate {
    name = "all-nix-packages";
    constituents = map ({ nix, ... }: nix) nixBenchConfigs;
  };

  all-nixpkgs-benchmarks = aggregate {
    constituents = concatMap attrValues [
      matrixed.nixpkgs.release
      matrixed.nixpkgs.release-attrpaths-superset
    ];
  };

  all-nixos-benchmarks = aggregate {
    constituents = [
      matrixed.nixos.release.iso_gnome
    ] ++ concatMap attrValues [ matrixed.nixos.release.closures ];
  };

  # An easy way to build all benchmarks
  # TODO: Should be able to just flatten the values of an attribute set.
  all-benchmarks = aggregate {
    constituents = [
      matrixed.all-nixpkgs-benchmarks
      matrixed.all-nixos-benchmarks
    ];
  };
}
// mapAttrsRecursiveCond (attrs: !(attrs ? attrPath) && !(attrs ? relativeFilePath)) (
  _: partialBenchConfig:
  aggregate {
    constituents = mkNixpkgsMatrix partialBenchConfig;
  }
) benchmarks
