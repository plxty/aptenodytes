{ lib, pkgs, ... }:
let
  # Independently encode the existing evil host intent, not its generated files.
  link = index: mac: lib.nameValuePair "${toString (30 + index)}-eth${toString index}" {
    matchConfig.MACAddress = mac;
    linkConfig = { MACAddressPolicy = "persistent"; Name = "eth${toString index}"; };
  };
  network = name: online: {
    matchConfig.Name = name;
    linkConfig = lib.optionalAttrs (online != null) { RequiredForOnline = online; };
    networkConfig = { LinkLocalAddressing = "no"; DHCP = "no"; };
  };
  bridgePort = n: lib.nameValuePair "${toString (52 + n)}-eth${toString n}"
    (lib.recursiveUpdate (network "eth${toString n}" "enslaved") {
      networkConfig.Bridge = "br-lan";
    });
in {
  services.resolved.enable = false;
  systemd.network = {
    enable = true;
    links = builtins.listToAttrs (lib.imap0 link [
      "58:47:ca:76:f8:26" "58:47:ca:76:f8:27"
      "58:47:ca:76:f8:28" "58:47:ca:76:f8:29"
    ]);
    netdevs."00-br-lan".netdevConfig = { Kind = "bridge"; Name = "br-lan"; };
    networks = {
      "50-lo" = (network "lo" "carrier") // {
        routes = [
          { Type = "local"; Destination = "198.18.0.0/15"; }
          { Type = "local"; Destination = "0.0.0.0/0"; Table = 100; }
        ];
        routingPolicyRules = [{ FirewallMark = "0xfeedc1a5"; Priority = 100; Table = 100; }];
      };
      "51-br-lan" = lib.recursiveUpdate (network "br-lan" "carrier") {
        networkConfig = {
          Address = "10.172.42.1/24";
          LinkLocalAddressing = "ipv6";
          DHCPPrefixDelegation = true;
          IPv6AcceptRA = false;
          IPv6SendRA = true;
        };
        dhcpPrefixDelegationConfig.Token = "::1";
        ipv6SendRAConfig = { Managed = true; OtherInformation = true; };
      };
      "55-ppp-wan" = lib.recursiveUpdate (network "ppp-wan" null) {
        networkConfig = {
          LinkLocalAddressing = "ipv6";
          DHCP = "ipv6";
          DefaultRouteOnDevice = true;
          KeepConfiguration = "static";
        };
        dhcpV6Config = {
          PrefixDelegationHint = "::/64";
          UseDNS = false;
          UseHostname = false;
          WithoutRA = "solicit";
        };
      };
    } // builtins.listToAttrs (map bridgePort [ 0 1 2 ]);
  };
  services.pppd = {
    enable = true;
    peers.ppp-wan = {
      pppoeInterface = "eth3";
      credentialsFile = "/etc/ppp/keys/ppp-wan";
    };
  };
}
