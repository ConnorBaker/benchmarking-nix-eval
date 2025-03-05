{
  description = "A Typst project";

  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/git-hooks.nix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];
      flake.overlays.default = final: _: {
        aggregate = final.callPackage ./aggregate { };
        # We map over benchmarks, so we don't want callPackage-added attributes present.
        benchmarks = import ./benchmarks {
          inherit (final) lib system;
        };
        timeFormatJson = final.callPackage ./timeFormatJson { };
        mkNixpkgsBench = final.callPackage ./mkNixpkgsBench { };
        matrixed = final.callPackage ./matrixed {
          # NOTE:
          # echo "1" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
          # sudo cpupower set -b 0
          # nom build --builders '' -L --max-jobs 1 --cores 1 .#matrixed.all-benchmarks
          numRuns = 20;
        };
      };
      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };

          legacyPackages = pkgs;

          pre-commit.settings.hooks = {
            # Formatter checks
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };

            # Nix checks
            deadnix.enable = true;
            nil.enable = true;
            statix.enable = true;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              # JSON, Markdown
              prettier = {
                enable = true;
                includes = [
                  "*.json"
                  "*.md"
                ];
                settings = {
                  embeddedLanguageFormatting = "auto";
                  printWidth = 120;
                  tabWidth = 2;
                };
              };

              # Nix
              nixfmt.enable = true;

              # Shell
              shellcheck.enable = true;
              shfmt.enable = true;
            };
          };
        };
    };
}
