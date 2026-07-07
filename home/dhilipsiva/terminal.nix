# Terminal emulator + multiplexer.
{ ... }:

{
  # zellij: the ~294-line hand-tuned KDL keybind block is kept as a source bridge
  # (attrset->KDL translation of ordered action sequences is fragile). Native
  # `programs.zellij.settings` translation is deferred. See CLEANUP.md.
  xdg.configFile."zellij/config.kdl".source = ../../.config/zellij/config.kdl;

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
