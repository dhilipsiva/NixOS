{ config, pkgs, ... }:

{
  home.username = "dhilipsiva";
  home.homeDirectory = "/home/dhilipsiva";
  home.stateVersion = "26.05";

  # --- SHELL CONFIG ---
  programs.bash = {
    enable = true;
    initExtra = ''
      eval $(starship init bash)
      eval $(atuin init bash)
    '';
    shellAliases = {
      g = "git";
      e = "hx";
      q = "exit";
      # Agent Alias (Goose)
      gdev = "goose run --model qwen2.5-coder:32b";
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g theme_display_date no
      eval $(starship init fish)
      eval $(atuin init fish)
    '';
    shellAliases = {
      g = "git";
      e = "hx";
      q = "exit";
      gdev = "goose run --model qwen2.5-coder:32b";
    };
  };

  # --- GIT CONFIG ---
  programs.git = {
    enable = true;
    # 26.05 home-manager renamed userName/userEmail → settings.user.* (Phase 3
    # restructures git config fully; this keeps eval warning-free meanwhile).
    settings.user = {
      name = "dhilipsiva";
      email = "dhilipsiva@pm.me";
    };
  };

  # --- AI AGENT CONFIG (Goose) ---
  home.sessionVariables = {
    # Point Goose to your Desktop's Ollama
    OPENAI_BASE_URL = "http://localhost:11434/v1"; 
    OPENAI_API_KEY = "ollama";
  };
}
