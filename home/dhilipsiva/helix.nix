# Helix — ported from .config/helix/config.toml + languages.toml.
{ ... }:

let
  # Shared JS/TS language-server stack: ts-language-server (no formatting) + biome.
  tsServers = [
    { name = "typescript-language-server"; except-features = [ "format" ]; }
    "biome"
  ];
in
{
  programs.helix = {
    enable = true;

    settings = {
      theme = "onedark";
      editor.cursor-shape = {
        insert = "bar";
        normal = "block";
        select = "underline";
      };
      editor.file-picker.hidden = false;
      editor.whitespace.render = "all";
      editor.indent-guides.render = true;
      editor.soft-wrap.enable = true;
    };

    languages = {
      language-server.biome = {
        command = "biome";
        args = [ "lsp-proxy" ];
      };
      language = [
        { name = "rust"; }
        { name = "javascript"; auto-format = true; language-servers = tsServers; }
        { name = "typescript"; auto-format = true; language-servers = tsServers; }
        { name = "tsx"; auto-format = true; language-servers = tsServers; }
        { name = "jsx"; auto-format = true; language-servers = tsServers; }
        {
          name = "json";
          language-servers = [
            { name = "vscode-json-language-server"; except-features = [ "format" ]; }
            "biome"
          ];
        }
      ];
    };
  };
}
