# Native official Linux app: preserve its bundled Electron and host environment.
{
  lib,
  callPackage,
  fetchurl,
  source,
  qemu_kvm,
  virtiofsd,
  OVMF,
  bubblewrap,
  socat,
  openssh,
  xdg-utils,
  nodejs,
  uv,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).claude-desktop;
  upstream = callPackage "${source}/nix/claude-desktop.nix" { };
in
upstream.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl { inherit (release) url hash; };
  # Electron can infer Wayland from XDG_SESSION_TYPE even without NIXOS_OZONE_WL.
  # A later explicit --ozone-platform argument overrides this per-app default.
  postFixup = (old.postFixup or "") + ''
    wrapProgram "$out/bin/claude-desktop" \
      --unset NIXOS_OZONE_WL \
      --add-flags "--ozone-platform=x11" \
      --prefix PATH : ${
        lib.makeBinPath [
          qemu_kvm
          virtiofsd
          bubblewrap
          socat
          openssh
          xdg-utils
          nodejs
          uv
        ]
      }
  '';
  passthru = (old.passthru or { }) // {
    cowork = {
      inherit qemu_kvm virtiofsd;
      firmware = OVMF.fd;
    };
  };
})
