{ lib, nixpkgs, pkgs, modules }:
let
  utils = import (nixpkgs + "/nixos/lib/utils.nix") {
    inherit lib pkgs;
    config = evaluated.config;
  };
  evaluated = lib.evalModules {
    specialArgs = { inherit pkgs utils nixpkgs; };
    modules = [
      (nixpkgs + "/nixos/modules/misc/meta.nix")
      (nixpkgs + "/nixos/modules/misc/assertions.nix")
      ../modules/system-base.nix
      ../modules/pppd.nix
    ] ++ modules;
  };
  failed = builtins.filter (item: !item.assertion) evaluated.config.assertions;
  config =
    if failed == [ ] then lib.showWarnings evaluated.config.warnings evaluated.config
    else throw ("Configuration assertions failed:\n" +
      lib.concatMapStringsSep "\n" (item: item.message) failed);
  manifest = import ./system-manifest.nix { inherit lib config; };
in
{
  inherit config manifest;
  inherit (evaluated) options;
  artifact = pkgs.configurationTree { inherit manifest; };
}
