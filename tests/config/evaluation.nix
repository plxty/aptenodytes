{ api, pkgs }:
let
  succeeds = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  system = modules: api.mkSystem { inherit pkgs modules; };
  service = { systemd.services.example.serviceConfig.ExecStart = "/usr/bin/true"; };
  extraNetwork = system [{
    environment.etc."systemd/network/99-extra.network".text = "[Match]\nName=eth9\n";
  }];
  overrideNetwork = system [{
    systemd.network = { enable = true; networks."50-example".matchConfig.Name = "eth0"; };
    environment.etc."systemd/network/50-example.network".source = {
      _type = "override"; priority = 50;
      content = pkgs.writeText "replacement.network" "[Match]\nName=eth1\n";
    };
  }];
  masked = system [{
    systemd.network = { enable = true; wait-online.enable = false; };
  }];
in {
  unmarkedNativePrefixRejected = !(succeeds ((pkgs.buildEnv {
    name = "bad-native-prefix"; paths = [{ outPath = "/usr"; }];
  }).drvPath));
  nestedStoreInputRejected = !(succeeds ((pkgs.buildEnv {
    name = "bad-nested-store-input";
    paths = [{ outPath = "${pkgs.writeTextDir "nested/file" "data"}/nested"; }];
  }).drvPath));
  extraNetworkFilePreserved = extraNetwork.manifest.files ? "etc/systemd/network/99-extra.network";
  explicitNetworkSourcePreserved = overrideNetwork.manifest.files."usr/lib/systemd/network/50-example.network"
    == toString overrideNetwork.config.environment.etc."systemd/network/50-example.network".source;
  fileCollisionRejected = !(succeeds (system [ service {
    environment.etc."systemd/system/example.service".text = "USER CONFIG";
  }]).artifact.drvPath);
  aliasCollisionRejected = !(succeeds (system [ service {
    systemd.services.example.aliases = [ "shared.service" ];
    systemd.services.other = {
      aliases = [ "shared.service" ]; serviceConfig.ExecStart = "/usr/bin/false";
    };
  }]).artifact.drvPath);
  falseAssertionRejected = !(succeeds (system [{
    assertions = [{ assertion = false; message = "expected assertion failure"; }];
  }]).artifact.drvPath);
  disabledVendorUnitMasked = masked.manifest.files."etc/systemd/system/systemd-networkd-wait-online.service" == "/dev/null"
    && !(masked.manifest.files ? "etc/systemd/system/systemd-networkd-wait-online.service.d/overrides.conf");
}
