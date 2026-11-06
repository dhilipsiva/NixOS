# Keep Nixpkgs' Linux resource/plugin fixes while following OpenAI's stable feed.
{ chatgpt, fetchurl }:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).chatgpt;
in
chatgpt.overrideAttrs (old: {
  inherit (release) version;
  src = fetchurl { inherit (release) url hash; };
  passthru = (old.passthru or { }) // {
    source = {
      inherit (release) version;
      src = { inherit (release) url hash; };
    };
  };
  # Upstream defaults to XWayland while native Wayland is experimental. The
  # user's explicit --ozone-platform=wayland still passes through unchanged.
  postFixup = (old.postFixup or "") + ''
    wrapProgram "$out/bin/chatgpt" \
      --unset NIXOS_OZONE_WL \
      --add-flags "--ozone-platform=x11"
  '';
})
