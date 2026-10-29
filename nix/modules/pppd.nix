# Compatibility module: reuse upstream services.pppd and preserve
# aptenodytes' current PPPoE behavior. This module installs no software.
{ config, lib, pkgs, nixpkgs, ... }:
let
  cfg = config.services.pppd;
  peers = builtins.filter (peer: peer.enable) (builtins.attrValues cfg.peers);
in {
  imports = [ (nixpkgs + "/nixos/modules/services/networking/pppd.nix") ];

  # Extend the upstream peer schema; all its existing options remain available.
  options.services.pppd.peers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options = {
        pppoeInterface = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[a-zA-Z0-9_.:-]+");
          default = null;
          description = "Native Ethernet interface; null leaves peer config manual.";
        };
        credentialsFile = lib.mkOption {
          type = lib.types.strMatching "/[^[:space:]]+";
          default = "/etc/ppp/keys/${config.name}";
          description = "Existing runtime credentials path; its contents are never imported.";
        };
      };
      config.config = lib.mkIf (config.pppoeInterface != null) (lib.mkBefore ''
        plugin pppoe.so
        ifname ${config.name}
        nic-${config.pppoeInterface}
        file ${config.credentialsFile}
        persist
        maxfail 0
        holdoff 10
        +ipv6 ipv6cp-use-ipaddr
        defaultroute
        usepeerdns
        noipdefault
      '');
    }));
  };

  config.systemd.services = lib.mkIf cfg.enable (builtins.listToAttrs (map (peer:
    lib.nameValuePair "pppd-${peer.name}" {
      # Keep the existing externally visible unit name. Unlike the previous
      # template-only spike, this is a complete definition of this instance.
      name = lib.mkForce "pppd@${peer.name}.service";
      description = "PPP connection for ${peer.name}";
      documentation = [ "man:pppd(8)" ];
      enableDefaultPath = false;
      unitConfig.StartLimitIntervalSec = 0;
      environment = {
        LD_PRELOAD = lib.mkForce null;
        NIX_REDIRECTS = lib.mkForce null;
      };
      # NixOS's original preStart writer produces a store script with native
      # /bin/bash. The interface is known, so no runtime awk/peer-file parsing.
      preStart = lib.mkIf (peer.pppoeInterface != null) ''
        exec ${pkgs.iproute2.executables.ip} link set up dev ${lib.escapeShellArg peer.pppoeInterface}
      '';
      serviceConfig = {
        ExecStart = lib.mkForce "${lib.getBin cfg.package}/sbin/pppd up_sdnotify nolog call ${peer.name}";
        ExecStop = "/bin/kill $MAINPID";
        ExecReload = "/bin/kill -HUP $MAINPID";
        StandardOutput = "null";
        RestartSec = lib.mkForce 1;
        ReadWritePaths = "/run/ /etc/ppp/";
        AmbientCapabilities = lib.mkForce "CAP_SYS_TTY_CONFIG CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN";
        CapabilityBoundingSet = lib.mkForce "CAP_SYS_TTY_CONFIG CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN";
        RestrictAddressFamilies = lib.mkForce "AF_NETLINK AF_PACKET AF_UNIX AF_PPPOX AF_ATMPVC AF_ATMSVC AF_INET AF_INET6 AF_IPX";
        ProtectProc = "invisible";
        ProtectClock = true;
        ProtectKernelLogs = true;
      };
    }) peers));
}
