# Browse/copy files from the existing Windows data partition without writing it.
{ config, pkgs, ... }:

let
  # One-shot reboot into Windows through the firmware's BootNext variable.
  rebootToWindows = pkgs.writeShellApplication {
    name = "reboot-to-windows";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.efibootmgr
      pkgs.gnused
      pkgs.systemd
    ];
    text = builtins.readFile ../../scripts/reboot-to-windows.sh;
  };
in
{
  environment.systemPackages = [ rebootToWindows ];

  # The stable greeter has only shutdown/reboot actions. Add a separate Windows
  # action on this host, leaving normal reboot and the laptop greeters intact.
  repo.greeter = {
    package = pkgs.tuigreet.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../../pkgs/tuigreet-windows.patch ];
    });
    extraArgs = [
      "--power-windows"
      # The greeter's nologin shell is deliberately absent from /etc/shells.
      # pkexec rejects that inherited SHELL even for an authorized command.
      "${pkgs.coreutils}/bin/env -u SHELL /run/wrappers/bin/pkexec --disable-internal-agent ${rebootToWindows}/bin/reboot-to-windows"
    ];
  };

  # There is no authentication agent before login. Permit only this immutable
  # helper for the active local greeter; it selects Windows and reboots together.
  # Keep sudo restricted to wheel and do not grant general efibootmgr access.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.policykit.exec" &&
          action.lookup("program") === "${rebootToWindows}/bin/reboot-to-windows" &&
          subject.user === "greeter" && subject.local && subject.active) {
        return polkit.Result.YES;
      }
    });
  '';
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
  home-manager.users.dhilipsiva.xdg.desktopEntries.reboot-to-windows = {
    name = "Reboot to Windows";
    comment = "Restart once into the Windows SSD; the boot order stays NixOS";
    exec = "${rebootToWindows}/bin/reboot-to-windows";
    icon = "system-reboot";
    terminal = false;
    categories = [ "System" ];
  };
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
