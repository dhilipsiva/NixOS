# Shells + prompt + history — ported from .config/fish/config.fish and the old
# inline home/default.nix. starship and atuin are enabled natively so their shell
# integrations REPLACE the manual `eval $(… init …)` / `atuin init … | source`
# lines (the old fish used the correct `atuin init fish | source`; the old bash
# used the wrong `eval $(atuin init bash)` — both are now owned by the modules).
{ ... }:

let
  shellAliases = {
    g = "git";
    e = "hx";
    q = "exit";
    # Agent alias (Goose)
    gdev = "goose run --model qwen2.5-coder:32b";
  };
in
{
  programs.starship.enable = true;
  programs.atuin = {
    enable = true;
    # config.toml was 99% commented defaults; only these two differ.
    settings = {
      enter_accept = true;
      sync.records = true;
    };
  };

  programs.fish = {
    enable = true;
    inherit shellAliases;
    interactiveShellInit = ''
      set -g theme_display_date no
    '';
  };

  programs.bash = {
    enable = true;
    inherit shellAliases;
  };

  # config.fish added ~/.cargo/bin to PATH; fnm line was commented out (dropped).
  home.sessionPath = [ "$HOME/.cargo/bin" ];
}
