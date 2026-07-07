# Terminal emulator — ported from .config/alacritty/alacritty.toml.
# (zellij is added here in Tier 2.)
{ ... }:

{
  programs.alacritty.enable = true;
  programs.alacritty.settings = {
    font = {
      normal.family = "Fira Code";
      bold.family = "Fira Code";
      italic.family = "Fira Code";
      bold_italic.family = "Fira Code";
      size = 16;
    };
    # Shift+Return sends ESC then CR (the original alacritty binding). fromJSON
    # turns the JSON unicode/CR escapes into the real control bytes.
    keyboard.bindings = [
      {
        key = "Return";
        mods = "Shift";
        chars = builtins.fromJSON ''"\u001b\r"'';
      }
    ];
  };
}
