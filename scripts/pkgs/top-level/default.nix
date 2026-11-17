{
  lib,
  system,
  toolchainId,
  shell ? "/usr/bin/bash",
  python ? "/usr/bin/python3",
}:
let
  # Deliberately do not import nixpkgs' package set. Unknown packages stay
  # unknown instead of falling back to a second package manager.
  pkgs = builders // nativePackages // {
    inherit lib system nativePackage;
    buildPackages = pkgs;
    configurationTree = import ../build-support/configuration-tree {
      inherit lib python;
      inherit (builders) runCommand;
    };
  };
  nativePackage = import ../build-support/native-package;
  nativePackages = import ./native-packages.nix { inherit nativePackage; };
  builders = import ../build-support/trivial-builders {
    inherit lib system toolchainId shell;
  };
in
pkgs
