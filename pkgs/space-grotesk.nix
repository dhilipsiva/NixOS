# Space Grotesk, QUINE's display face (headlines). Not in nixpkgs; upstream release, OFL-1.1.
{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "space-grotesk";
  version = "2.0.0";

  src = fetchzip {
    url = "https://github.com/floriankarsten/space-grotesk/releases/download/${finalAttrs.version}/SpaceGrotesk-${finalAttrs.version}.zip";
    # The archive also carries a __MACOSX directory beside the font folder.
    stripRoot = false;
    hash = "sha256-niwd5E3rJdGmoyIFdNcK5M9A9P2rCbpsyZCl7CDv7I8=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/fonts/opentype SpaceGrotesk-${finalAttrs.version}/otf/*.otf
    install -Dm644 -t $out/share/doc/space-grotesk SpaceGrotesk-${finalAttrs.version}/OFL.txt
    runHook postInstall
  '';

  meta = {
    description = "Proportional sans-serif typeface derived from Space Mono";
    homepage = "https://github.com/floriankarsten/space-grotesk";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
