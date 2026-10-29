{ lib, builders }:
lib.makeOverridable ({ name, paths, pathsToLink ? [ "/" ], extraOutputsToInstall ? [ ],
  postBuild ? "", meta ? { }, passthru ? { } }:
let
  outputs = lib.concatMap (pkg: [ pkg ] ++
    map (output: pkg.${output}) (builtins.filter (output: pkg ? ${output}) extraOutputsToInstall)) paths;
  description = {
    kind = "environment";
    inherit pathsToLink;
    paths = map (pkg:
      if pkg.isNative or false then { inherit (pkg) nativeFiles; }
      else let path = toString pkg; in
        assert lib.assertMsg (lib.isStorePath path && builtins.dirOf path == builtins.storeDir)
          "pseudoBuildEnv: generated inputs must be store output roots; declare native paths with isNative/nativeFiles";
        { store = path; }) outputs;
  };
in (builders.buildSpec name description).overrideAttrs (old: {
  inherit meta;
  passthru = passthru // { inherit paths; };
  buildCommand = old.buildCommand + "\n" + postBuild;
}))
