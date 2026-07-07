# Containers, non-Nix dynamic binaries, and Android device access.
{ ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  # Run pre-built dynamically-linked binaries (VSCode server, etc.).
  programs.nix-ld.enable = true;

  # Android device access for the plugdev group. (`programs.adb.enable` was
  # removed on 26.05 — systemd 258 handles the uaccess rule automatically; the
  # `adb` command itself comes from android-tools in packages.nix.)
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", ATTR{idProduct}=="4ee7", MODE="0660", GROUP="plugdev"
  '';
}
