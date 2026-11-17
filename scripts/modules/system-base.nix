# Only the configuration interfaces needed by PPP and upstream unit rendering.
# No NixOS package installation, boot, users, or activation modules are loaded.
{ config, lib, pkgs, utils, ... }:
let
  inherit (lib) mkOption types;
  option = type: default: mkOption { inherit type default; };
  systemd = utils.systemdUtils;
  etcFile = types.submodule ({ name, config, ... }: {
    options = {
      text = option (types.nullOr types.lines) null;
      source = mkOption {
        type = types.path;
        description = "Generated configuration file or an explicit source.";
      };
    };
    config.source = lib.mkIf (config.text != null)
      (lib.mkDefault (pkgs.writeText (lib.strings.sanitizeDerivationName (baseNameOf name)) config.text));
  });
in
{
  options = {
    environment.etc = option (types.attrsOf etcFile) { };
    systemd = {
      enableStrictShellChecks = option types.bool false;
      globalEnvironment = option (types.attrsOf (types.nullOr types.str)) { };
      defaultPath = option (types.listOf types.package) [ ];
      services = option systemd.types.services { };
      units = option systemd.types.units { };
    };
  };

  config = {
    assertions = [
      {
        assertion = let names = map (service: service.name) (builtins.attrValues config.systemd.services);
          in builtins.length names == builtins.length (lib.unique names);
        message = "Systemd services must have unique rendered unit names.";
      }
      {
        assertion = builtins.all (name:
          systemd.lib.unitNameType.check name && config.systemd.units.${name}.name == name
        ) (builtins.attrNames config.systemd.units);
        message = "Systemd unit names must be valid and match their attribute keys.";
      }
      {
        assertion = builtins.all (service: service.startAt == [ ])
          (builtins.attrValues config.systemd.services);
        message = "systemd.services.*.startAt is unsupported: this stage does not generate timers.";
      }
      {
        assertion = builtins.all (unit: unit.overrideStrategy == "asDropinIfExists")
          (builtins.attrValues config.systemd.units);
        message = "Systemd drop-ins are unsupported: this stage generates complete owned units.";
      }
    ];
    systemd.units = lib.mapAttrs' (_: service:
      lib.nameValuePair service.name (systemd.lib.serviceToUnit service)
    ) config.systemd.services;
  };
}
