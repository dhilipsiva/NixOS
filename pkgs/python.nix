# Latest stable CPython while Nixpkgs catches up. Keep its complete interpreter
# metadata/package scope consistent, not just the displayed version string.
{ pkgs }:

let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).python;
  parts = pkgs.lib.splitString "." release.version;
  major = builtins.elemAt parts 0;
  minor = builtins.elemAt parts 1;
  patch = builtins.elemAt parts 2;
  # Select the matching interpreter recipe when a new stable minor is released.
  interpreter = pkgs.${"python${major}${minor}"};
in interpreter.override {
  sourceVersion = {
    inherit major minor patch;
    suffix = "";
  };
  inherit (release) hash;
}
