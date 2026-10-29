{ config, lib, pkgs, utils, ... }:
let
  inherit (lib) mkOption types;
  su = utils.systemdUtils;
  option = type: default: mkOption { inherit type default; };
  etcType = types.attrsOf (types.submodule ({ name, config, ... }: {
    options = {
      text = option (types.nullOr types.lines) null;
      source = mkOption { type = types.path; };
    };
    config.source = lib.mkIf (config.text != null)
      (lib.mkDefault (pkgs.writeText (baseNameOf name) config.text));
  }));
  render = renderer: defs: lib.mapAttrs' (_: def:
    lib.nameValuePair def.name (renderer def)) defs;
in {
  # Deliberately bounded module surface: nothing from the NixOS boot closure,
  # activation, system profile, NSS, or systemd package installation is imported.
  options = {
    systemd = {
      package = option types.package pkgs.systemd;
      enableStrictShellChecks = option types.bool false;
      globalEnvironment = option (types.attrsOf (types.nullOr types.str)) { };
      additionalUpstreamSystemUnits = option (types.listOf types.str) [ ];
      services = option su.types.services { };
      sockets = option su.types.sockets { };
      units = option su.types.units { };
    };
    environment.etc = option etcType { };
    users.users = option (types.attrsOf (types.submodule {
      options.group = mkOption { type = types.str; };
    })) { };
    services.resolved.enable = option types.bool false;
    networking = {
      useDHCP = option types.bool false;
      iproute2 = {
        enable = option types.bool false;
        rttablesExtraConfig = option types.lines "";
      };
    };
    boot.initrd = {
      systemd = {
        enable = option (types.enum [ false ]) false;
        # Upstream's mkIf false definitions still require declared options.
        additionalUpstreamUnits = option (types.listOf types.str) [ ];
        contents = option types.attrs { };
        dbus.enable = option types.bool false;
        users = option types.attrs { };
        groups = option types.attrs { };
        services = option types.attrs { };
        sockets = option types.attrs { };
        storePaths = option (types.listOf types.str) [ ];
      };
      kernelModules = option (types.listOf types.str) [ ];
      network = {
        enable = option types.bool false;
        flushBeforeStage2 = option types.bool false;
      };
    };
    assertions = option (types.listOf types.unspecified) [ ];
  };
  config.systemd.units =
    render su.lib.serviceToUnit config.systemd.services
    // render su.lib.socketToUnit config.systemd.sockets;
}
