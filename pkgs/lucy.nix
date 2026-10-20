{
  lib,
  pkgs,
  nibli,
  identity,
  inventory,
  inputHelper,
  dmiHelper,
  # The host's own Ollama build serves as the client for lucy setup-model, so a
  # Vulkan host does not also carry the CUDA distribution.
  ollama,
  # Nibli pins the Ollama model for the desktop GPU. A host with less memory
  # passes { name, digest, context } to pin a smaller tag at build time; null
  # leaves Nibli's source untouched.
  model ? null,
}:
let
  rustPlatform = pkgs.makeRustPlatform {
    cargo = pkgs.rust-toolchain;
    rustc = pkgs.rust-toolchain;
  };
  cli = rustPlatform.buildRustPackage {
    pname = "nibli-lucy";
    version = "0.2.0-desktop";
    src = nibli;
    cargoLock.lockFile = "${nibli}/Cargo.lock";
    cargoBuildFlags = [
      "-p"
      "lucy-cli"
    ];
    cargoTestFlags = [
      "-p"
      "lucy-cli"
    ];
  };
  python = pkgs.python3.withPackages (p: [
    p.pygobject3
    p.pycairo
  ]);
  gtkTypelibs = lib.makeSearchPath "lib/girepository-1.0" [
    pkgs.gtk4
    pkgs.pango.out
    pkgs.gdk-pixbuf
    pkgs.graphene
    pkgs.gobject-introspection
    pkgs.glib.out
    pkgs.harfbuzz
  ];
  # Only the three pinned constants change; every other line of the runtime is
  # Nibli's. The greps fail the build if that file's layout moves.
  desktopSource =
    if model == null then
      "${nibli}/lucy-cli/desktop"
    else
      pkgs.runCommand "lucy-desktop-${lib.replaceStrings [ ":" ] [ "-" ] model.name}" { } ''
        cp -r ${nibli}/lucy-cli/desktop $out
        chmod -R u+w $out
        sed -i \
          -e "s|^MODEL = .*|MODEL = '${model.name}'|" \
          -e "s|^DIGEST = .*|DIGEST = '${model.digest}'|" \
          -e "s|^CONTEXT = .*|CONTEXT = ${toString model.context}|" \
          $out/lucy_desktop/model.py
        grep -Fxq "MODEL = '${model.name}'" $out/lucy_desktop/model.py
        grep -Fxq "DIGEST = '${model.digest}'" $out/lucy_desktop/model.py
        grep -Fxq "CONTEXT = ${toString model.context}" $out/lucy_desktop/model.py
      '';
  vsix = pkgs.runCommand "lucy-vscode-1.0.0.vsix" { nativeBuildInputs = [ pkgs.zip ]; } ''
    mkdir extension
    cp ${nibli}/lucy-cli/desktop/adapters/vscode/* extension/
    # Store sources are read-only; VS Code updates package.json metadata after
    # extracting a VSIX and preserves the file modes recorded in the archive.
    chmod u+w extension/*
    cat > extension.vsixmanifest <<'EOF'
    <?xml version="1.0" encoding="utf-8"?>
    <PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
      <Metadata><Identity Language="en-US" Id="lucy" Version="1.0.0" Publisher="nibli"/><DisplayName>Ask Lucy</DisplayName><Description xml:space="preserve">Explicit shared Lucy memory</Description><Tags/><Categories>Other</Categories><Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.95.0"/></Properties></Metadata>
      <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/>
      <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
    </PackageManifest>
    EOF
    cat > '[Content_Types].xml' <<'EOF'
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="js" ContentType="application/javascript"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>
    EOF
    zip -qr "$out" extension extension.vsixmanifest '[Content_Types].xml'
  '';
  runtimePaths = [
    pkgs.bubblewrap
    pkgs.ripgrep
    pkgs.coreutils
    pkgs.systemd
    pkgs.hyprland
    pkgs.grim
    pkgs.ydotool
    pkgs.gtk3
    pkgs.polkit
    ollama
    python
    pkgs.vscode
  ];
  runtime = pkgs.writeShellScript "lucy-desktop" ''
    export PYTHONPATH=${desktopSource}
    export GI_TYPELIB_PATH=${gtkTypelibs}
    export PATH=${lib.makeBinPath runtimePaths}:$PATH
    exec ${python}/bin/python3 -m lucy_desktop "$@"
  '';
in
pkgs.symlinkJoin {
  name = "lucy-desktop";
  paths = [ cli ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    cat > "$out/bin/lucy-native-host" <<EOF
    #!${pkgs.runtimeShell}
    exec "$out/bin/lucy" native-host
    EOF
    chmod +x "$out/bin/lucy-native-host"
    wrapProgram "$out/bin/lucy" \
      --set LUCY_DESKTOP_EXECUTABLE ${runtime} \
      --set LUCY_EXECUTABLE "$out/bin/lucy" \
      --set LUCY_NATIVE_HOST "$out/bin/lucy-native-host" \
      --set LUCY_VSIX ${vsix} \
      --set LUCY_IDENTITY ${identity} \
      --set LUCY_INVENTORY ${inventory} \
      --set LUCY_INPUT_HELPER ${inputHelper} \
      --set LUCY_DMI_HELPER ${dmiHelper} \
      --set YDOTOOL_SOCKET /run/lucy-input/socket \
      --prefix PATH : "$out/bin" \
      --set LUCY_COMMAND_PATH ${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.ripgrep
          pkgs.git
          pkgs.python3
          pkgs.nix
        ]
      }
    mkdir -p "$out/share/lucy"
    ln -s ${desktopSource}/adapters/browser "$out/share/lucy/browser-extension"
    ln -s ${vsix} "$out/share/lucy/lucy.vsix"
    ln -s ${inventory} "$out/share/lucy/integrations.json"
  '';
  passthru = {
    inherit
      cli
      runtime
      vsix
      python
      gtkTypelibs
      desktopSource
      model
      ;
  };
}
