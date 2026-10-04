{
  writeShellApplication,
  python3,
  git,
  nix,
  openssh,
  util-linux,
  coreutils,
  rsync,
  age,
  sops,
  ssh-to-age,
  sbctl,
  sbsigntool,
  efitools,
  openssl,
  systemd,
  systemdUkify,
  cryptsetup,
  flatpak,
  nvd,
}:
writeShellApplication {
  name = "nixosctl";
  runtimeInputs = [
    python3
    git
    nix
    openssh
    util-linux
    coreutils
    rsync
    age
    sops
    ssh-to-age
    sbctl
    sbsigntool
    efitools
    openssl
    systemd
    systemdUkify
    cryptsetup
    flatpak
    nvd
  ];
  text = ''
    export NIXOSCTL_LAUNCHER="$0"
    export PYTHONDONTWRITEBYTECODE=1
    exec python3 ${../scripts}/nixosctl.py "$@"
  '';
  meta.description = "Check, publish and stage the shared NixOS repository";
}
