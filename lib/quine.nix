# QUINE, the design system of dhilipsiva.dev, as one token set for every desktop surface.
# Source of truth: dhilipsiva.dev static/assets/tokens/{colors,typography,effects}.css.
# Colours are hex without `#`; `hex` and `rgba` render them for each format. The desktop is
# dark-first, as QUINE is; the site's light theme ("daylight nihilism") is in `light`.
let
  palette = {
    # The void: backgrounds, deepest first.
    void1000 = "07070A";
    void900 = "0B0B10";
    void800 = "111119";
    void700 = "181822";
    void600 = "20202C";
    void500 = "2A2A38";
    void400 = "3A3A4A";
    # Foreground: warm whites, never pure.
    paper100 = "F4F3EF";
    paper200 = "C9C8C2";
    muted = "908F9A";
    faint = "8B8A95";
    ghost = "3C3C49";
    # Ember: the single accent.
    ember50 = "FFE9E0";
    ember300 = "FF9A6F";
    ember500 = "F2542D";
    ember600 = "D8431B";
    ember700 = "B23413";
    onEmber = "2A0A00";
    # Phosphor: alive, success.
    phosphor300 = "8BF0CE";
    phosphor500 = "38E3A6";
    phosphor700 = "16A877";
    # Quanta: symbolic, used sparingly.
    quanta300 = "B6A8FF";
    quanta500 = "8B7CF6";
    quanta700 = "5B4ACB";
    # Signals.
    amber = "F5B544";
    sky = "4DB8FF";
    crimson = "FF4D5E";
  };
in
rec {
  inherit palette;

  # Semantic names, as the site's components consume them.
  color = with palette; {
    bgSunken = void1000;
    bg = void900;
    raised = void800;
    card = void700;
    inset = void600;
    border = void500;
    borderStrong = void400;
    strong = paper100;
    body = paper200;
    inherit muted faint ghost;
    accent = ember500;
    accentHover = ember300;
    accentPress = ember600;
    inherit onEmber;
    alive = phosphor500;
    symbol = quanta500;
    success = phosphor500;
    warning = amber;
    info = sky;
    danger = crimson;
  };

  # "Daylight nihilism": the site's light theme. Ember keeps burning.
  light = {
    bg = "F4F3EF";
    sunken = "E9E8E2";
    raised = "FBFAF7";
    card = "FFFFFF";
    inset = "EFEEE8";
    strong = "16161C";
    body = "2E2E38";
    muted = "5E5E6C";
    faint = "6B6A75";
    border = "DAD8D0";
    borderStrong = "C2BFB5";
    link = palette.ember700;
  };

  # Code, as the site's terminal and prose colour it.
  code = with palette; {
    prompt = phosphor500;
    keyword = ember300;
    function = sky;
    string = phosphor300;
    number = phosphor300;
    type = quanta300;
    comment = faint;
    punctuation = muted;
  };

  # The 16 terminal colours. Bright red is ember, so the brand reaches every terminal and the
  # console; plain red stays crimson for errors. Shades marked "derived" are not QUINE tokens.
  ansi = with palette; {
    black = void600;
    red = crimson;
    green = phosphor500;
    yellow = amber;
    blue = sky;
    magenta = quanta500;
    cyan = phosphor300;
    white = paper200;
    brightBlack = "5E5E6C";
    brightRed = ember500;
    brightGreen = phosphor300;
    brightYellow = "FFD08A"; # derived
    brightBlue = "8FD3FF"; # derived
    brightMagenta = quanta300;
    brightCyan = "B5F7E3"; # derived
    brightWhite = paper100;
  };
  # The same, in VT order (black, red, green, yellow, blue, magenta, cyan, white; then bright).
  ansiList = with ansi; [
    black
    red
    green
    yellow
    blue
    magenta
    cyan
    white
    brightBlack
    brightRed
    brightGreen
    brightYellow
    brightBlue
    brightMagenta
    brightCyan
    brightWhite
  ];

  font = {
    mono = "IBM Plex Mono";
    sans = "IBM Plex Sans";
    serif = "IBM Plex Serif";
    display = "Space Grotesk";
    # Waybar's icons are Nerd Font glyphs; this font carries only those.
    symbols = "Symbols Nerd Font Mono";
  };

  # Tight, engineered radii in pixels.
  radius = {
    xs = 2;
    sm = 4;
    md = 6;
    lg = 10;
    xl = 16;
  };

  hex = c: "#${c}";
  # "F2542D" -> [ 242 84 45 ]
  channels =
    c:
    let
      digit =
        d:
        let
          i = builtins.stringLength (builtins.head (builtins.split d "0123456789ABCDEF"));
        in
        if i < 16 then i else builtins.stringLength (builtins.head (builtins.split (d) "0123456789abcdef"));
      byte = i: digit (builtins.substring i 1 c) * 16 + digit (builtins.substring (i + 1) 1 c);
    in
    [
      (byte 0)
      (byte 2)
      (byte 4)
    ];
  # `rgba "F2542D" "0.16"` -> "rgba(242, 84, 45, 0.16)"
  rgba = c: alpha: "rgba(${builtins.concatStringsSep ", " (map toString (channels c))}, ${alpha})";
  # KDE colour values: "F2542D" -> "242,84,45"
  kde = c: builtins.concatStringsSep "," (map toString (channels c));
}
