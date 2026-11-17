# PPP intent from profiles/iglu/evil, without importing its networkd setup.
{ ... }:
{
  services.pppd = {
    enable = true;
    peers.ppp-wan = {
      pppoeInterface = "eth3";
      credentialsFile = "/etc/ppp/keys/ppp-wan";
    };
  };
}
