# System-wide essentials shared by root, recovery shells and services.
# Applications and developer tools live in the user's Home Manager profile
# (home/dhilipsiva/packages.nix); packages that enabled modules already install
# (curl, openssh, docker, the login shell) are not listed again.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    wget
    tree
    unzip
    rsync
    openssl
    openconnect # VPN client; runs privileged
    libinput # input-device diagnostics
    helix # root and recovery shells use the same editor as the user
  ];

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
