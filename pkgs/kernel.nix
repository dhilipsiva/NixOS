{ pkgs }:
let
  inherit (pkgs) lib;
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).linux;
  series = lib.versions.majorMinor release.version;
  # The Nixpkgs recipe for the release's own series (linuxPackages_7_2 for 7.2.x), never
  # linuxPackages_latest: that moves to a newer series on Nixpkgs' schedule, which halted the
  # 2026-10-20 nightly when it became 7.3 while the verified release stayed 7.2.11.
  attribute = "linuxPackages_" + lib.replaceStrings [ "." ] [ "_" ] series;
  base =
    (pkgs.${attribute}
      or (throw "Kernel ${release.version} needs Nixpkgs' ${attribute} recipe, which this Nixpkgs no longer has; move the release to a supported series.")
    ).kernel;
in
assert lib.assertMsg (
  lib.versions.majorMinor base.version == series
) "${attribute} is ${base.version}, not the ${series} series.";
if base.version == release.version then
  base
else
  base.override {
    argsOverride = {
      inherit (release) version;
      modDirVersion = lib.versions.pad 3 release.version;
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v${lib.versions.major release.version}.x/linux-${release.version}.tar.xz";
        inherit (release) hash;
      };
    };
  }
