# Shell, prompt and history. Fish is the login shell; starship, atuin, zoxide
# and direnv integrate through their modules' default fish hooks.
{ ... }:

{
  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.atuin = {
    enable = true;
    settings = {
      enter_accept = true;
      sync.records = true;
    };
  };

  programs.fish = {
    enable = true;
    # Fish 4.9 removed the Python manpage generator used by HM 26.05. Packaged
    # vendor completions remain enabled.
    generateCompletions = false;
    shellAliases = {
      g = "git";
      e = "hx";
      q = "exit";
    };
  };

  # Rust comes from the pinned stable Nix toolchain. Do not prepend legacy
  # ~/.cargo/bin rustup shims that could silently select an older compiler.
}
