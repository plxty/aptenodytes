{ nativePackage }:
{
  ppp = nativePackage {
    name = "ppp";
    executables.pppd = "/usr/sbin/pppd";
  };
  # Upstream checks this string-valued definition before mkForce removes its
  # LD_PRELOAD setting. It is never built, loaded, or retained in our units.
  libredirect = nativePackage { name = "libredirect"; };
  iproute2 = nativePackage {
    name = "iproute2";
    mainProgram = "ip";
    executables.ip = "/usr/bin/ip";
  };
}
