# Helix with its language servers wrapped onto PATH, coloured as QUINE colours code.
{ pkgs, ... }:

let
  quine = import ../../lib/quine.nix;
  inherit (quine) palette code;
  c = quine.hex;
  # Ember over the void for selections (derived: QUINE's accent-soft, then stronger).
  selection = "#301715";
  selectionPrimary = "#471E18";
  # Shared JS/TS language-server stack: ts-language-server (no formatting) + biome.
  tsServers = [
    {
      name = "typescript-language-server";
      except-features = [ "format" ];
    }
    "biome"
  ];
in
{
  programs.helix = {
    enable = true;
    extraPackages = with pkgs; [
      typescript-language-server
      biome
      vscode-langservers-extracted
    ];

    settings = {
      theme = "quine";
      editor = {
        # The mode indicator takes the theme's mode colours (normal ember, insert phosphor).
        color-modes = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        file-picker.hidden = false;
        whitespace.render = "all";
        indent-guides.render = true;
        soft-wrap.enable = true;
      };
    };

    themes.quine = with palette; {
      # Interface
      "ui.background".bg = c void900;
      "ui.text" = c paper200;
      "ui.text.focus" = c paper100;
      "ui.text.inactive" = c muted;
      "ui.cursor" = {
        fg = c onEmber;
        bg = c ember300;
      };
      "ui.cursor.primary" = {
        fg = c onEmber;
        bg = c ember500;
      };
      "ui.cursor.match" = {
        bg = c void500;
        modifiers = [ "bold" ];
      };
      "ui.selection".bg = selection;
      "ui.selection.primary".bg = selectionPrimary;
      "ui.cursorline.primary".bg = c void800;
      "ui.linenr" = c quine.ansi.brightBlack;
      "ui.linenr.selected" = c paper100;
      "ui.gutter".bg = c void900;
      "ui.statusline" = {
        fg = c paper200;
        bg = c void800;
      };
      "ui.statusline.inactive" = {
        fg = c muted;
        bg = c void900;
      };
      "ui.statusline.normal" = {
        fg = c onEmber;
        bg = c ember500;
        modifiers = [ "bold" ];
      };
      "ui.statusline.insert" = {
        fg = c void1000;
        bg = c phosphor500;
        modifiers = [ "bold" ];
      };
      "ui.statusline.select" = {
        fg = c void1000;
        bg = c quanta300;
        modifiers = [ "bold" ];
      };
      "ui.popup" = {
        fg = c paper200;
        bg = c void700;
      };
      "ui.popup.info" = {
        fg = c paper200;
        bg = c void700;
      };
      "ui.window" = c void500;
      "ui.help" = {
        fg = c paper200;
        bg = c void700;
      };
      "ui.menu" = {
        fg = c paper200;
        bg = c void700;
      };
      "ui.menu.selected" = {
        fg = c paper100;
        bg = c void600;
      };
      "ui.menu.scroll" = {
        fg = c void400;
        bg = c void700;
      };
      "ui.picker.header" = c ember300;
      "ui.virtual.whitespace" = c void500;
      "ui.virtual.indent-guide" = c void500;
      "ui.virtual.ruler".bg = c void800;
      "ui.virtual.inlay-hint" = c faint;
      "ui.virtual.jump-label" = {
        fg = c ember500;
        modifiers = [ "bold" ];
      };
      "ui.bufferline" = {
        fg = c muted;
        bg = c void900;
      };
      "ui.bufferline.active" = {
        fg = c paper100;
        bg = c void700;
      };
      "ui.highlight".bg = c void700;
      # Diagnostics
      error = c crimson;
      warning = c amber;
      info = c sky;
      hint = c phosphor500;
      "diagnostic.error".underline = {
        color = c crimson;
        style = "curl";
      };
      "diagnostic.warning".underline = {
        color = c amber;
        style = "curl";
      };
      "diagnostic.info".underline = {
        color = c sky;
        style = "curl";
      };
      "diagnostic.hint".underline = {
        color = c phosphor500;
        style = "curl";
      };
      # Code, as the site's terminal and prose colour it
      comment = {
        fg = c code.comment;
        modifiers = [ "italic" ];
      };
      keyword = c code.keyword;
      "keyword.directive" = c quanta300;
      function = c code.function;
      "function.macro" = c quanta300;
      "function.builtin" = c code.function;
      string = c code.string;
      "string.regexp" = c amber;
      "string.special" = c amber;
      constant = c code.number;
      "constant.numeric" = c code.number;
      "constant.builtin" = c ember300;
      "constant.character.escape" = c amber;
      type = c code.type;
      "type.builtin" = c code.type;
      constructor = c code.type;
      variable = c paper200;
      "variable.builtin" = c ember300;
      "variable.parameter" = c paper100;
      "variable.other.member" = c paper200;
      label = c sky;
      namespace = c paper100;
      attribute = c amber;
      tag = c ember300;
      operator = c code.punctuation;
      punctuation = c code.punctuation;
      special = c ember500;
      # Markup and diffs
      "markup.heading" = {
        fg = c paper100;
        modifiers = [ "bold" ];
      };
      "markup.list" = c ember500;
      "markup.bold".modifiers = [ "bold" ];
      "markup.italic".modifiers = [ "italic" ];
      "markup.strikethrough".modifiers = [ "crossed_out" ];
      "markup.link.url" = {
        fg = c ember300;
        underline.style = "line";
      };
      "markup.link.text" = c sky;
      "markup.quote" = c muted;
      "markup.raw" = c phosphor300;
      "diff.plus" = c phosphor500;
      "diff.minus" = c crimson;
      "diff.delta" = c amber;
    };

    languages = {
      language-server.biome = {
        command = "biome";
        args = [ "lsp-proxy" ];
      };
      language = [
        { name = "rust"; }
        {
          name = "javascript";
          auto-format = true;
          language-servers = tsServers;
        }
        {
          name = "typescript";
          auto-format = true;
          language-servers = tsServers;
        }
        {
          name = "tsx";
          auto-format = true;
          language-servers = tsServers;
        }
        {
          name = "jsx";
          auto-format = true;
          language-servers = tsServers;
        }
        {
          name = "json";
          language-servers = [
            {
              name = "vscode-json-language-server";
              except-features = [ "format" ];
            }
            "biome"
          ];
        }
      ];
    };
  };
}
