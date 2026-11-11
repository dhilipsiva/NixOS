# The QUINE wallpaper: the void, the blueprint grid fading out from the centre, a faint ember
# glow and the site's mark, rendered from the tokens to a 3840x2160 PNG. No text, so no fonts
# are needed while it builds.
{
  runCommand,
  librsvg,
  writeText,
}:

let
  quine = import ../lib/quine.nix;
  inherit (quine) palette hex;
  width = 3840;
  height = 2160;
  # QUINE's 24px grid at the desktop's 1.5 scale.
  cell = 36;
  mark = 264;
  svg = writeText "quine-wallpaper.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="${toString width}" height="${toString height}" viewBox="0 0 ${toString width} ${toString height}">
      <defs>
        <pattern id="grid" width="${toString cell}" height="${toString cell}" patternUnits="userSpaceOnUse">
          <path d="M ${toString cell} 0 L 0 0 0 ${toString cell}" fill="none" stroke="${hex palette.ghost}" stroke-opacity="0.6" stroke-width="1.5"/>
        </pattern>
        <radialGradient id="fade" cx="50%" cy="50%" r="62%">
          <stop offset="0" stop-color="#fff" stop-opacity="0.9"/>
          <stop offset="0.55" stop-color="#fff" stop-opacity="0.35"/>
          <stop offset="1" stop-color="#fff" stop-opacity="0"/>
        </radialGradient>
        <mask id="vignette"><rect width="100%" height="100%" fill="url(#fade)"/></mask>
        <radialGradient id="glow" cx="50%" cy="50%" r="50%">
          <stop offset="0" stop-color="${hex palette.ember500}" stop-opacity="0.16"/>
          <stop offset="1" stop-color="${hex palette.ember500}" stop-opacity="0"/>
        </radialGradient>
      </defs>
      <rect width="100%" height="100%" fill="${hex palette.void900}"/>
      <rect width="100%" height="100%" fill="url(#grid)" mask="url(#vignette)"/>
      <circle cx="${toString (width / 2)}" cy="${toString (height / 2)}" r="560" fill="url(#glow)"/>
      <g transform="translate(${toString ((width - mark) / 2)} ${toString ((height - mark) / 2)}) scale(${toString (mark / 120.0)})">
        <rect x="6" y="6" width="108" height="108" rx="22" fill="${hex palette.void900}" stroke="${hex palette.void500}" stroke-width="2"/>
        <g stroke="${hex palette.ember500}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round" fill="none">
          <path d="M37 38 L55 60 L37 82"/>
          <path d="M83 38 L65 60 L83 82"/>
        </g>
        <circle cx="60" cy="60" r="6" fill="${hex palette.phosphor500}"/>
      </g>
    </svg>
  '';
in
runCommand "quine-wallpaper"
  {
    nativeBuildInputs = [ librsvg ];
    passthru.svg = svg;
  }
  ''
    mkdir -p $out
    cp ${svg} $out/quine.svg
    rsvg-convert --width ${toString width} --height ${toString height} --output $out/quine.png ${svg}
  ''
