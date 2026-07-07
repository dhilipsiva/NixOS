{ ... }:

{
  imports = [
    ./shells.nix # fish, bash, starship, atuin
    ./git.nix
    ./terminal.nix # alacritty (+ zellij in Tier 2)
    ./helix.nix
    ./services.nix # user timers (time notification)
  ];

  home.username = "dhilipsiva";
  home.homeDirectory = "/home/dhilipsiva";
  home.stateVersion = "26.05";

  # --- AI AGENT CONFIG (Goose) ---
  home.sessionVariables = {
    # Point Goose to your Desktop's Ollama
    OPENAI_BASE_URL = "http://localhost:11434/v1";
    OPENAI_API_KEY = "ollama";
  };
}
