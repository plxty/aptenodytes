{ nixpkgs, homeManager }:
let
  lib = nixpkgs.lib;
  mergeOwned = sets: builtins.foldl' (acc: attrs:
    builtins.foldl' (current: name:
      if current ? ${name} && current.${name} != attrs.${name} then
        throw "configuration destination collision: ${name}"
      else current // { ${name} = attrs.${name}; }
    ) acc (builtins.attrNames attrs)
  ) { } sets;
in rec {
  mkPkgs = { system, toolchainId, shell ? "/bin/bash", python ? "/usr/bin/python3" }: let
    upstream = import nixpkgs { inherit system; };
    builders = import ./native-builders.nix { inherit lib system toolchainId shell python; };
    yaml = { }: {
      inherit (upstream.formats.yaml { }) type;
      generate = name: value: builders.buildSpec name { kind = "yaml"; inherit value; };
    };
    modulePkgs = upstream // (import ./native-pkgs.nix { inherit lib; }) // builders // {
    buildEnv = import ./pseudo-build-env.nix { inherit lib builders; };
    formats = (import (nixpkgs + "/pkgs/pkgs-lib/formats.nix") { inherit lib; pkgs = modulePkgs; }) // {
      inherit yaml;
      yaml_1_1 = yaml;
      json = { }: {
        inherit (upstream.formats.json { }) type;
        generate = name: value: builders.writeText name (builtins.toJSON value + "\n");
      };
    };
    };
  in modulePkgs;

  mkSystem = { pkgs, modules }: let
    utils = import (nixpkgs + "/nixos/lib/utils.nix") { inherit lib pkgs; config = rawConfig; };
    evaluated = lib.evalModules {
      specialArgs = { inherit pkgs utils nixpkgs; };
      modules = [
        ../modules/system-base.nix
        (nixpkgs + "/nixos/modules/misc/meta.nix")
        (nixpkgs + "/nixos/modules/system/boot/networkd.nix")
        ../modules/pppd.nix
      ] ++ modules;
    };
    rawConfig = evaluated.config;
    failed = builtins.filter (item: !item.assertion) rawConfig.assertions;
    config = if failed == [ ] then rawConfig else
      throw ("System configuration assertions failed:\n" + lib.concatMapStringsSep "\n" (item: item.message) failed);
    vendorUnits = config.systemd.additionalUpstreamSystemUnits;
    isVendor = name: builtins.elem name vendorUnits;
    networkFiles = lib.mapAttrs' (name: unit: lib.nameValuePair
      "usr/lib/systemd/network/${name}"
      (toString config.environment.etc."systemd/network/${name}".source)) config.systemd.network.units;
    relocatedEtcNames = map (name: "systemd/network/${name}") (builtins.attrNames config.systemd.network.units);
    etcFiles = lib.mapAttrs' (name: file: lib.nameValuePair "etc/${name}" (toString file.source))
      (lib.filterAttrs (name: _: !(builtins.elem name relocatedEtcNames)) config.environment.etc);
    unitFiles = lib.mapAttrs' (name: unit: lib.nameValuePair
      ("etc/systemd/system/${name}" + lib.optionalString (unit.enable && isVendor name) ".d/overrides.conf")
      (if unit.enable then "${unit.unit}/${name}" else "/dev/null")) config.systemd.units;
    linkEntries = lib.concatMap (unit: let
      target = if unit.enable && isVendor unit.name then "/usr/lib/systemd/system/${unit.name}" else unit.name;
      dependencies = suffix: targets: map (parent:
        lib.nameValuePair "etc/systemd/system/${parent}.${suffix}/${unit.name}"
          (if lib.hasPrefix "/" target then target else "../${target}")) targets;
    in dependencies "wants" unit.wantedBy
      ++ dependencies "requires" unit.requiredBy
      ++ dependencies "upholds" unit.upheldBy
      ++ map (alias: lib.nameValuePair "etc/systemd/system/${alias}" target) unit.aliases
    ) (builtins.attrValues config.systemd.units);
    links = mergeOwned (map (entry: { ${entry.name} = entry.value; }) linkEntries);
    manifest = {
      schema = 1;
      kind = "system";
      inherit links vendorUnits;
      files = mergeOwned [ networkFiles etcFiles unitFiles ];
      services = lib.mapAttrs' (_: svc: lib.nameValuePair svc.name {
        inherit (svc) enable wantedBy restartIfChanged reloadIfChanged stopIfChanged notSocketActivated;
        restartTriggers = map toString (lib.flatten svc.restartTriggers);
        reloadTriggers = map toString (lib.flatten svc.reloadTriggers);
      }) config.systemd.services;
    };
  in {
    inherit config manifest;
    artifact = pkgs.buildSpec "aptenodytes-system-config" {
      kind = "tree";
      inherit manifest;
      inherit (manifest) files links;
    };
  };

  mkHome = { pkgs, modules }: let
    evaluated = homeManager.lib.homeManagerConfiguration {
      inherit pkgs;
      minimal = true;
      modules = map (path: homeManager + "/modules/programs/${path}") [
        # Schemas referenced by minimal's shells and Git's pager assertion.
        # Importing these declarations does not enable their applications.
        "git.nix" "fish.nix" "man" "home-manager.nix"
        "delta.nix" "diff-highlight.nix" "diff-so-fancy.nix"
        "difftastic.nix" "patdiff.nix" "riff.nix" "jujutsu.nix"
      ] ++ [
        ../modules/home-base.nix
        { _module.args.pkgs = lib.mkForce pkgs; }
      ] ++ modules;
    };
    config = evaluated.config;
    manifest = {
      schema = 1;
      kind = "home";
      inherit (config.home) username homeDirectory;
      files = {
        "home-files" = toString config.home-files;
        "home-path" = toString config.home.path;
      };
    };
  in {
    inherit config manifest;
    artifact = pkgs.buildSpec "aptenodytes-home-config" {
      kind = "tree";
      inherit manifest;
      inherit (manifest) files;
    };
  };
}
