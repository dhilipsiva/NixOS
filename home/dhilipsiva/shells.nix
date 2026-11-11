# Shell, prompt and history. Fish is the login shell; starship, atuin, zoxide
# and direnv integrate through their modules' default fish hooks. Colours come
# from QUINE, the site's design system (lib/quine.nix).
{ ... }:

let
  quine = import ../../lib/quine.nix;
  inherit (quine) palette code hex;
in
{
  # QUINE's prompt: a `//` comment mark in ember, the place in warm white, and a
  # phosphor prompt that turns crimson after a failure. No emoji module symbols.
  programs.starship = {
    enable = true;
    settings = with palette; {
      format = "[//](bold ${hex ember500}) $directory$git_branch$git_state$git_status$nix_shell$jobs$cmd_duration$line_break$character";
      add_newline = true;
      directory = {
        style = "bold ${hex paper100}";
        truncation_length = 3;
        read_only = " ro";
        read_only_style = hex amber;
      };
      git_branch = {
        format = "[$branch]($style) ";
        style = hex quanta300;
      };
      git_state.style = hex amber;
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = hex amber;
      };
      nix_shell = {
        format = "[nix:$state]($style) ";
        style = hex sky;
      };
      jobs.style = hex muted;
      cmd_duration = {
        format = "[$duration]($style) ";
        style = hex faint;
      };
      character = {
        success_symbol = "[❯](bold ${hex phosphor500})";
        error_symbol = "[❯](bold ${hex crimson})";
        vimcmd_symbol = "[❮](bold ${hex ember500})";
      };
    };
  };
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
      theme.name = "quine";
    };
    themes.quine = with palette; {
      theme.name = "quine";
      colors = {
        AlertInfo = hex sky;
        AlertWarn = hex amber;
        AlertError = hex crimson;
        Annotation = hex faint;
        Base = hex paper200;
        Guidance = hex muted;
        Important = hex ember500;
        Title = hex paper100;
      };
    };
  };

  # Unknown commands name the Nix package that provides them, and `, <cmd>`
  # runs a package once, both from the weekly nix-index-database input.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  programs.fish = {
    enable = true;
    # Fish 4.9 removed the Python manpage generator used by HM 26.05. Packaged
    # vendor completions remain enabled.
    generateCompletions = false;
    # QUINE's code colours for the command line (fish takes hex without `#`).
    interactiveShellInit = with palette; ''
      set -g fish_color_normal ${paper200}
      set -g fish_color_command ${code.function}
      set -g fish_color_keyword ${code.keyword}
      set -g fish_color_param ${paper200}
      set -g fish_color_option ${paper100}
      set -g fish_color_quote ${code.string}
      set -g fish_color_redirection ${quanta300}
      set -g fish_color_operator ${ember300}
      set -g fish_color_escape ${amber}
      set -g fish_color_end ${code.punctuation}
      set -g fish_color_error ${crimson}
      set -g fish_color_comment ${code.comment} --italics
      set -g fish_color_autosuggestion ${quine.ansi.brightBlack}
      set -g fish_color_valid_path --underline
      set -g fish_color_cwd ${ember300}
      set -g fish_color_user ${phosphor500}
      set -g fish_color_host ${paper200}
      set -g fish_color_selection --background=${void600}
      set -g fish_color_search_match --background=${void600}
      set -g fish_pager_color_prefix ${ember500} --bold
      set -g fish_pager_color_completion ${paper200}
      set -g fish_pager_color_description ${muted}
      set -g fish_pager_color_progress ${faint}
      set -g fish_pager_color_selected_background --background=${void600}
    '';
    shellAliases = {
      g = "git";
      e = "hx";
      q = "exit";
      # Claude Code with the separate NuFlights account and settings.
      claude-nuflights = "CLAUDE_CONFIG_DIR=~/.claude-nuflights command claude";
    };
  };

  # Rust comes from the pinned stable Nix toolchain. Do not prepend legacy
  # ~/.cargo/bin rustup shims that could silently select an older compiler.
}
