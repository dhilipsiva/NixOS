# NetworkManager with systemd-resolved and an nftables firewall. Wi-Fi
# credentials stay in NetworkManager's local store.
{ ... }:

{
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };
  services.resolved.enable = true;

  # nftables backend for the NixOS firewall. Nothing listens on the network by
  # default; services bind to localhost or open ports explicitly per host.
  networking.nftables.enable = true;
}
