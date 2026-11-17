{ api, pkgs }:
let
  lib = pkgs.lib;
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  system = modules: api.mkSystem { inherit pkgs modules; };
  ppp = {
    services.pppd = {
      enable = true;
      peers.ppp-wan.pppoeInterface = "eth3";
    };
  };
  example = system [ ppp ];
  manual = system [{
    services.pppd = {
      enable = true;
      peers.dialup = { config = "noauth\n"; autostart = false; };
      peers.disabled.enable = false;
    };
  }];
  overridden = system [ ppp {
    environment.etc."ppp/peers/ppp-wan".source =
      lib.mkForce (pkgs.writeText "replacement-peer" "noauth\n");
  } ];
  sourceFile = system [{
    environment.etc.provider.source = ./fixtures/provider;
    systemd.services.example = {
      serviceConfig.ExecStart = "/usr/bin/true";
      restartTriggers = [ ./fixtures/provider ];
      reloadTriggers = [ ./fixtures/provider ];
    };
  }];
in
{
  nativePackagesAreReferences = toString pkgs.ppp == "/usr"
    && pkgs.ppp.isNative && !(pkgs.ppp ? drvPath)
    && lib.getExe pkgs.iproute2 == "/usr/bin/ip";
  noNixPackageFallback = !(pkgs ? hello) && !(pkgs ? stdenv) && pkgs.libredirect.isNative;
  disabledByDefault = (system [ ]).manifest.files == { };
  pppInstanceNamePreserved = example.manifest.files ? "etc/systemd/system/pppd@ppp-wan.service";
  pppEnablementIsRelative = example.manifest.links.
    "etc/systemd/system/multi-user.target.wants/pppd@ppp-wan.service" == "../pppd@ppp-wan.service";
  noNixRuntimeInjection = example.config.systemd.services.pppd-ppp-wan.environment.LD_PRELOAD == null
    && example.config.systemd.services.pppd-ppp-wan.environment.NIX_REDIRECTS == null;
  manualPeerHasNoPreStart = !(manual.config.systemd.services.pppd-dialup.serviceConfig ? ExecStartPre);
  autostartFalseHasNoLink = manual.manifest.links == { };
  disabledPeerIsAbsent = !(manual.manifest.files ? "etc/ppp/peers/disabled");
  explicitPeerSourcePreserved = overridden.manifest.files."etc/ppp/peers/ppp-wan"
    == toString overridden.config.environment.etc."ppp/peers/ppp-wan".source;
  missingCredentialsRemainExternal = succeeds (system [ ppp {
    services.pppd.peers.ppp-wan.credentialsFile = "/not-installed/ppp-credentials";
  } ]).artifact.drvPath;
  literalSourcesRetainContext = builtins.hasContext sourceFile.manifest.files."etc/provider"
    && sourceFile.manifest.files."etc/provider" == "${./fixtures/provider}";
  literalTriggersRetainContext = builtins.all builtins.hasContext
    (sourceFile.manifest.services."example.service".restartTriggers
      ++ sourceFile.manifest.services."example.service".reloadTriggers);
  invalidCredentialsRejected = builtins.all (path: !(succeeds (system [ ppp {
    services.pppd.peers.ppp-wan.credentialsFile = path;
  } ]).artifact.drvPath)) [ "/keys/a\"b" "/keys/a'b" "/keys/a\\b" "/keys/a#b" "/keys/a b" ];
  nonNativePackageRejected = !(succeeds (system [ ppp {
    services.pppd.package = pkgs.writeTextDir "sbin/pppd" "not a native package";
  } ]).artifact.drvPath);
  invalidPeerNameRejected = !(succeeds (system [ ppp {
    services.pppd.peers.ppp-wan.name = "../escape";
  } ]).artifact.drvPath);
  duplicatePeerNamesRejected = !(succeeds (system [ ppp {
    services.pppd.peers.second.name = "ppp-wan";
  } ]).artifact.drvPath);
  falseAssertionRejected = !(succeeds (system [{
    assertions = [{ assertion = false; message = "expected failure"; }];
  }]).artifact.drvPath);
  fileCollisionRejected = !(succeeds (system [ ppp {
    environment.etc."systemd/system/pppd@ppp-wan.service".text = "collision";
  } ]).artifact.drvPath);
  aliasCollisionRejected = !(succeeds (system [ ppp {
    systemd.services.pppd-ppp-wan.aliases = [ "shared.service" ];
    systemd.services.other = {
      aliases = [ "shared.service" ];
      serviceConfig.ExecStart = "/usr/bin/true";
    };
  } ]).artifact.drvPath);
  maskedUnitIsDevNull = (system [ ppp {
    systemd.services.pppd-ppp-wan.enable = false;
  } ]).manifest.files."etc/systemd/system/pppd@ppp-wan.service" == "/dev/null";
  duplicateUnitNamesRejected = !(succeeds (system [ ppp {
    systemd.services.other = {
      name = lib.mkForce "pppd@ppp-wan.service";
      serviceConfig.ExecStart = "/usr/bin/true";
    };
  } ]).artifact.drvPath);
  renamedUnitRejected = !(succeeds (system [{
    systemd.units."example.service" = { name = "different.service"; text = ""; };
  }]).artifact.drvPath);
  invalidUnitNameRejected = !(succeeds (system [{
    systemd.units."bad/name.service".text = "";
  }]).artifact.drvPath);
  timersRejected = !(succeeds (system [ ppp {
    systemd.services.pppd-ppp-wan.startAt = "daily";
  } ]).artifact.drvPath);
  dropinsRejected = !(succeeds (system [ ppp {
    systemd.services.pppd-ppp-wan.overrideStrategy = "asDropin";
  } ]).artifact.drvPath);
  unsupportedModulesFail = !(succeeds (system [{
    systemd.network.enable = true;
  }]).artifact.drvPath);
}
