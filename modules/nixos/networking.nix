# NetworkManager, firewall, and the Focus-Mode hosts blocklist.
{ ... }:

{
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.hosts = {
    "127.0.0.1" = [ "reddit.com" "www.reddit.com" ]; # Focus Mode
  };
}
