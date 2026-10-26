# Use Nixpkgs' native packaging with Google's checksum-pinned stable CLI release.
{
  antigravity-cli,
  fetchurl,
  makeWrapper,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).antigravity-cli;
in
antigravity-cli.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl {
    inherit (release) url hash;
  };
  nativeBuildInputs = old.nativeBuildInputs ++ [ makeWrapper ];
  postFixup = (old.postFixup or "") + ''
    wrapProgram "$out/bin/agy" --set AGY_CLI_DISABLE_AUTO_UPDATE true
  '';
})
