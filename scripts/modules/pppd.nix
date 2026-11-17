# Reuse upstream PPP options, peer generation and service hardening. Override
# only NixOS-specific runtime assumptions and the existing ridgeni differences.
{ config, lib, pkgs, nixpkgs, ... }:
let
  cfg = config.services.pppd;
  peers = builtins.filter (peer: peer.enable) (builtins.attrValues cfg.peers);
  peerNames = map (peer: peer.name) peers;
  validPeerName = name:
    builtins.match "[a-zA-Z0-9_.-]+" name != null && name != "." && name != "..";
in
{
  imports = [ (nixpkgs + "/nixos/modules/services/networking/pppd.nix") ];

  options.services.pppd.peers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
      options = {
        pppoeInterface = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "[a-zA-Z0-9_.:-]+");
          default = null;
          description = "Native PPPoE interface; null leaves the peer configuration manual.";
        };
        credentialsFile = lib.mkOption {
          type = lib.types.addCheck (lib.types.strMatching "/[^[:space:]]+")
            (path: builtins.all (char: !(builtins.elem char [ "\\" "\"" "'" "#" ]))
              (lib.stringToCharacters path));
          default = "/etc/ppp/keys/${config.name}";
          description = ''
            External credentials path, written as one unquoted PPP token.
            Whitespace, quotes, backslashes and # are unsupported. Its contents
            are never read or copied into the store.
          '';
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.isAttrs cfg.package && (cfg.package.isNative or false);
        message = "services.pppd.package must reference a native package.";
      }
      {
        assertion = builtins.all validPeerName peerNames;
        message = "PPP peer names must contain only letters, digits, _, . and - (not . or ..).";
      }
      {
        assertion = builtins.length peerNames == builtins.length (lib.unique peerNames);
        message = "Enabled PPP peers must have unique names.";
      }
    ];

    systemd.services = builtins.listToAttrs (map (peer:
      lib.nameValuePair "pppd-${peer.name}" {
        # Preserve the current ridgeni instance names, not pppd-<name>.service.
        name = lib.mkForce "pppd@${peer.name}.service";
        description = "PPP connection for ${peer.name}";
        documentation = [ "man:pppd(8)" ];
        enableDefaultPath = false;
        unitConfig.StartLimitIntervalSec = 0;
        environment = {
          LD_PRELOAD = lib.mkForce null;
          NIX_REDIRECTS = lib.mkForce null;
        };
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
      }
    ) peers);
  };
}
