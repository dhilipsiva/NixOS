# Terminal emulator and multiplexer, dressed as QUINE's terminal (lib/quine.nix).
{ lib, pkgs, ... }:

let
  quine = import ../../lib/quine.nix;
  inherit (quine) palette ansi hex;
  # One Zellij theme component: its text and background, then four emphasis colours.
  component = name: base: background: emphasis: ''
    ${name} {
      base "${hex base}"
      background "${hex background}"
      ${lib.concatImapStringsSep "
  " (i: c: ''emphasis_${toString (i - 1)} "${hex c}"'') emphasis}
    }
  '';
  emphasis = with palette; [
    ember500
    phosphor500
    quanta300
    sky
  ];
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell.program = "${pkgs.fish}/bin/fish";
      # Bold/italic faces derive from the normal family. The point size is a
      # logical size; the compositor scales it (1.5x on the desktop).
      font = {
        normal.family = quine.font.mono;
        size = 12;
      };
      window.padding = {
        x = 10;
        y = 8;
      };
      # The site's terminal (`.term`): the deepest void, warm body text, an ember
      # cursor and ember selection.
      colors = {
        primary = {
          background = hex palette.void1000;
          foreground = hex palette.paper200;
          bright_foreground = hex palette.paper100;
          dim_foreground = hex palette.muted;
        };
        cursor = {
          cursor = hex palette.ember500;
          text = hex palette.onEmber;
        };
        vi_mode_cursor = {
          cursor = hex palette.phosphor500;
          text = hex palette.void1000;
        };
        selection = {
          background = hex palette.ember500;
          text = hex palette.onEmber;
        };
        search = {
          matches = {
            background = hex palette.void500;
            foreground = hex palette.paper100;
          };
          focused_match = {
            background = hex palette.amber;
            foreground = hex palette.void1000;
          };
        };
        footer_bar = {
          background = hex palette.void700;
          foreground = hex palette.paper200;
        };
        normal = with ansi; {
          black = hex black;
          red = hex red;
          green = hex green;
          yellow = hex yellow;
          blue = hex blue;
          magenta = hex magenta;
          cyan = hex cyan;
          white = hex white;
        };
        bright = with ansi; {
          black = hex brightBlack;
          red = hex brightRed;
          green = hex brightGreen;
          yellow = hex brightYellow;
          blue = hex brightBlue;
          magenta = hex brightMagenta;
          cyan = hex brightCyan;
          white = hex brightWhite;
        };
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
    settings = {
      default_shell = "fish";
      theme = "quine";
    };
    # The focused frame and the selected tab are ember, like Hyprland's focus border.
    themes.quine = with palette; ''
      themes {
        quine {
          ${component "text_unselected" paper200 void900 emphasis}
          ${component "text_selected" paper100 void600 emphasis}
          ${component "ribbon_unselected" paper200 void700 [
            crimson
            paper100
            ember300
            sky
          ]}
          ${component "ribbon_selected" onEmber ember500 [
            void900
            paper100
            quanta500
            sky
          ]}
          ${component "table_title" ember500 void900 emphasis}
          ${component "table_cell_unselected" paper200 void800 emphasis}
          ${component "table_cell_selected" paper100 void600 emphasis}
          ${component "list_unselected" paper200 void800 emphasis}
          ${component "list_selected" paper100 void600 emphasis}
          ${component "frame_unselected" void500 void900 emphasis}
          ${component "frame_selected" ember500 void900 emphasis}
          ${component "frame_highlight" amber void900 emphasis}
          ${component "exit_code_success" phosphor500 void900 emphasis}
          ${component "exit_code_error" crimson void900 emphasis}
          multiplayer_user_colors {
            player_1 "${hex ember500}"
            player_2 "${hex phosphor500}"
            player_3 "${hex quanta300}"
            player_4 "${hex sky}"
            player_5 "${hex amber}"
            player_6 "${hex crimson}"
            player_7 "${hex ember300}"
            player_8 "${hex phosphor300}"
            player_9 "${hex quanta500}"
            player_10 "${hex paper200}"
          }
        }
      }
    '';
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
  };

  # The system monitor Waybar opens. Each host installs btop; this writes only its
  # configuration and the QUINE theme.
  programs.btop = {
    enable = true;
    package = null;
    settings = {
      color_theme = "quine";
      theme_background = true;
      rounded_corners = false;
    };
    themes.quine = with palette; ''
      theme[main_bg]="${hex void900}"
      theme[main_fg]="${hex paper200}"
      theme[title]="${hex paper100}"
      theme[hi_fg]="${hex ember500}"
      theme[selected_bg]="${hex void600}"
      theme[selected_fg]="${hex paper100}"
      theme[inactive_fg]="${hex quine.ansi.brightBlack}"
      theme[graph_text]="${hex muted}"
      theme[meter_bg]="${hex void600}"
      theme[proc_misc]="${hex phosphor300}"
      theme[cpu_box]="${hex void400}"
      theme[mem_box]="${hex void400}"
      theme[net_box]="${hex void400}"
      theme[proc_box]="${hex void400}"
      theme[div_line]="${hex void500}"
      theme[temp_start]="${hex phosphor500}"
      theme[temp_mid]="${hex amber}"
      theme[temp_end]="${hex crimson}"
      theme[cpu_start]="${hex phosphor500}"
      theme[cpu_mid]="${hex amber}"
      theme[cpu_end]="${hex ember500}"
      theme[free_start]="${hex phosphor700}"
      theme[free_mid]="${hex phosphor500}"
      theme[free_end]="${hex phosphor300}"
      theme[cached_start]="${hex quanta700}"
      theme[cached_mid]="${hex quanta500}"
      theme[cached_end]="${hex quanta300}"
      theme[available_start]="${hex sky}"
      theme[available_mid]="${hex sky}"
      theme[available_end]="${hex paper200}"
      theme[used_start]="${hex ember700}"
      theme[used_mid]="${hex ember500}"
      theme[used_end]="${hex ember300}"
      theme[download_start]="${hex phosphor700}"
      theme[download_mid]="${hex phosphor500}"
      theme[download_end]="${hex phosphor300}"
      theme[upload_start]="${hex ember700}"
      theme[upload_mid]="${hex ember500}"
      theme[upload_end]="${hex ember300}"
      theme[process_start]="${hex phosphor500}"
      theme[process_mid]="${hex amber}"
      theme[process_end]="${hex ember500}"
    '';
  };
}
