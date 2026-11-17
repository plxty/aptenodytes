{ nixpkgs }:
let
  lib = import (nixpkgs + "/lib");
in
{
  mkPkgs = args: import ../pkgs/top-level (args // { inherit lib; });
  mkSystem = { pkgs, modules ? [ ] }: import ./eval-config.nix {
    inherit lib nixpkgs pkgs modules;
  };
}
