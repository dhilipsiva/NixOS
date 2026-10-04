{ pkgs }:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).linux;
  base = pkgs.linuxPackages_latest.kernel;
  sameSeries =
    pkgs.lib.versions.majorMinor base.version == pkgs.lib.versions.majorMinor release.version;
in
if base.version == release.version then
  base
else
  assert pkgs.lib.assertMsg sameSeries
    "New stable kernel series needs a matching Nixpkgs kernel recipe before publication.";
  base.override {
    argsOverride = {
      inherit (release) version;
      modDirVersion = pkgs.lib.versions.pad 3 release.version;
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v${pkgs.lib.versions.major release.version}.x/linux-${release.version}.tar.xz";
        inherit (release) hash;
      };
    };
  }
