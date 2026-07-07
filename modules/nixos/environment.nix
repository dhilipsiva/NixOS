# Global environment variables.
{ ... }:

{
  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
    # XDG_CONFIG_HOME override REMOVED in Phase 3: dotfiles are now managed by
    # home-manager, which writes to the default ~/.config. (The old override
    # pointed at ~/.files/.config, i.e. the repo, which no longer holds the
    # live configs.) DRI_PRIME dropped — the monitor is wired directly to the GPU.
  };
}
