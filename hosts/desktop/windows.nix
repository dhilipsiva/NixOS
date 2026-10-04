# Browse/copy files from the existing Windows data partition without writing it.
{ config, pkgs, ... }:

{
  # Preserve the uid of the installed desktop account for NTFS file ownership.
  users.users.dhilipsiva.uid = 1000;

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/263CE1813CE14BFD";
    fsType = "ntfs3";
    options = [
      "ro"
      "nosuid"
      "nodev"
      "noexec"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=5min"
      "x-systemd.device-timeout=5s"
      "uid=${toString config.users.users.dhilipsiva.uid}"
      "gid=100"
      "umask=0077"
    ];
  };

  home-manager.users.dhilipsiva.gtk.gtk3.bookmarks = [ "file:///mnt/windows Windows" ];
  home-manager.users.dhilipsiva.xdg.desktopEntries.windows-files = {
    name = "Windows files";
    comment = "Browse the Windows SSD (read-only)";
    exec = "${pkgs.kdePackages.dolphin}/bin/dolphin /mnt/windows";
    icon = "drive-harddisk";
    terminal = false;
    categories = [
      "System"
      "FileTools"
    ];
  };
}
