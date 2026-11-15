# NetworkManager with systemd-resolved and an nftables firewall. Wi-Fi
# credentials stay in NetworkManager's local store.
{ ... }:

{
  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };
  services.resolved.enable = true;

  # nftables backend for the NixOS firewall. Services bind to localhost or open
  # ports explicitly; the only shared opening is Ollama's API (ollama.nix).
  networking.nftables.enable = true;
}
