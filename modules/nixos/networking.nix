# NetworkManager with systemd-resolved, an nftables firewall and the Focus-Mode
# hosts blocklist. Wi-Fi credentials stay in NetworkManager's local store.
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

  # Focus Mode: resolve distracting sites to loopback on every machine.
  # /etc/hosts has no wildcards, so each subdomain that serves the site is listed
  # explicitly; browser DNS-over-HTTPS would bypass this if it were turned on.
  networking.hosts =
    let
      blockedSites = [
        # YouTube
        "youtube.com"
        "www.youtube.com"
        "m.youtube.com"
        "music.youtube.com"
        "studio.youtube.com"
        "youtube-nocookie.com"
        "www.youtube-nocookie.com"
        "youtu.be"
        "youtubei.googleapis.com"
        # Facebook
        "facebook.com"
        "www.facebook.com"
        "m.facebook.com"
        "web.facebook.com"
        "fb.com"
        "www.fb.com"
        "fb.me"
        # LinkedIn
        "linkedin.com"
        "www.linkedin.com"
        "lnkd.in"
        # Instagram
        "instagram.com"
        "www.instagram.com"
        "i.instagram.com"
        "instagr.am"
        # Reddit
        "reddit.com"
        "www.reddit.com"
        "old.reddit.com"
        "new.reddit.com"
        "np.reddit.com"
        "m.reddit.com"
        "redd.it"
        "i.redd.it"
        "v.redd.it"
        "preview.redd.it"
      ];
    in
    {
      "127.0.0.1" = blockedSites;
      "::1" = blockedSites;
    };
}
