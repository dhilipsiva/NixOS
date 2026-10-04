# Helix with its language servers wrapped onto PATH.
{ pkgs, ... }:

let
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
      theme = "onedark";
      editor = {
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
