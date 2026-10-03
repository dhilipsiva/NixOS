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
  };
in
{
  programs.starship.enable = true;
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    # config.toml was 99% commented defaults; only these two differ.
    settings = {
      enter_accept = true;
      sync.records = true;
    };
  };

  programs.fish = {
    enable = true;
    # Fish 4.9 removed the Python manpage generator used by HM 26.05. Packaged
    # vendor completions and Atuin's integration remain enabled.
    generateCompletions = false;
    inherit shellAliases;
    interactiveShellInit = ''
      set -g theme_display_date no
    '';
  };

  programs.bash = {
    enable = true;
    inherit shellAliases;
  };

  # Rust comes from the pinned stable Nix toolchain. Do not prepend legacy
  # ~/.cargo/bin rustup shims that could silently select an older compiler.
}
