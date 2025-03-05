{ lib, system }:
let
  inherit (lib.attrsets) genAttrs;
in
{
  nixpkgs = {
    release-attrpaths-superset = genAttrs [ "names" "paths" ] (name: {
      attrPath = [ name ];
      relativeFilePath = "pkgs/top-level/release-attrpaths-superset.nix";
    });
    release = genAttrs [ "firefox-unwrapped" ] (name: {
      attrPath = [ name ];
      relativeFilePath = "pkgs/top-level/release.nix";
    });
  };

  nixos.release = {
    iso_gnome = {
      attrPath = [
        "iso_gnome"
        system
      ];
      relativeFilePath = "nixos/release.nix";
    };
    closures = genAttrs [ "kde" "lapp" "smallContainer" ] (name: {
      attrPath = [
        "closures"
        name
        system
      ];
      relativeFilePath = "nixos/release.nix";
    });
  };
}
