# Terminal emulator and multiplexer.
{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell.program = "${pkgs.fish}/bin/fish";
      # Bold/italic faces derive from the normal family. The point size is a
      # logical size; the compositor scales it (1.5x on the desktop).
      font = {
        normal.family = "Fira Code";
        size = 12;
      };
      # Shift+Return sends ESC then CR. fromJSON turns the JSON escapes into the
      # real control bytes.
      keyboard.bindings = [
        {
          key = "Return";
          mods = "Shift";
          chars = builtins.fromJSON ''"\u001b\r"'';
        }
      ];
    };
  };

  # Upstream keybindings (the former KDL file restated the old defaults) with
  # fish in new panes. No shell hook: zellij starts only when asked.
  programs.zellij = {
    enable = true;
    settings.default_shell = "fish";
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
  };
}
