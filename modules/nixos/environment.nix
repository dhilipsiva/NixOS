# Global environment variables.
{ ... }:

{
  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
    # Serves the raw .config/ tree directly. Phase 3 migrates those dotfiles into
    # home-manager and REMOVES this override (see PLAN.md / TODO.md Phase 3).
    XDG_CONFIG_HOME = "/home/dhilipsiva/.files/.config";
    # DRI_PRIME dropped on the desktop — the monitor is wired directly to the GPU.
  };
}
