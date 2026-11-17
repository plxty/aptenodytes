# Describe the owned filesystem tree. Construction is separate from activation.
{ lib, config }:
let
  mergeOwned = sets: lib.foldl' (result: entries:
    lib.foldl' (current: name:
      if current ? ${name} && current.${name} != entries.${name} then
        throw "configuration destination collision: ${name}"
      else
        current // { ${name} = entries.${name}; }
    ) result (builtins.attrNames entries)
  ) { } sets;

  # Unlike toString on a path, interpolation copies a literal source into
  # the store and preserves its dependency context for the artifact's closure.
  reference = value: if builtins.isPath value then "${value}" else toString value;
  units = builtins.attrValues config.systemd.units;
  etcFiles = lib.mapAttrsToList (name: file: {
    "etc/${name}" = reference file.source;
  }) config.environment.etc;
  unitFiles = map (unit: {
    "etc/systemd/system/${unit.name}" =
      if unit.enable then "${unit.unit}/${unit.name}" else "/dev/null";
  }) units;

  unitLinks = unit:
    let
      dependencies = suffix: parents: map (parent: {
        "etc/systemd/system/${parent}.${suffix}/${unit.name}" = "../${unit.name}";
      }) parents;
    in
    dependencies "wants" unit.wantedBy
    ++ dependencies "requires" unit.requiredBy
    ++ dependencies "upholds" unit.upheldBy
    ++ map (alias: { "etc/systemd/system/${alias}" = unit.name; }) unit.aliases;
in
{
  schema = 1;
  kind = "system";
  files = mergeOwned (etcFiles ++ unitFiles);
  links = mergeOwned (lib.concatMap unitLinks units);
  services = mergeOwned (lib.mapAttrsToList (_: service: {
    ${service.name} = {
      inherit (service)
        enable wantedBy restartIfChanged reloadIfChanged stopIfChanged notSocketActivated;
      restartTriggers = map reference (lib.flatten service.restartTriggers);
      reloadTriggers = map reference (lib.flatten service.reloadTriggers);
    };
  }) config.systemd.services);
}
