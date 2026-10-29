{ lib }:
let
  native = name: nativeFiles: let self = {
    type = "derivation";
    inherit name nativeFiles;
    isNative = true;
    outPath = "/usr";
    outputs = [ "out" ];
    out = self;
    meta = { };
  }; in self;
in lib.genAttrs [ "coreutils" "findutils" "gnugrep" "gnused" "systemd" "lndir" ]
  (name: native name { }) // {
  ppp = native "ppp" { "sbin/pppd" = "/usr/sbin/pppd"; };
  git = (native "git" { "bin/git" = "/usr/bin/git"; }) // {
    meta.mainProgram = "git";
  };
  iproute2 = (native "iproute2" { "bin/ip" = "/bin/ip"; }) // {
    executables.ip = "/bin/ip";
  };
}
