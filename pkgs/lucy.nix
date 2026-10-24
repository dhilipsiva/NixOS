{
  lib,
  pkgs,
  lucy,
  identity,
  inventory,
  inputHelper,
  dmiHelper,
  # The host's own Ollama build serves as the client for lucy setup-model, so a
  # Vulkan host does not also carry the CUDA distribution.
  ollama,
  # Lucy pins the Ollama model for the desktop GPU. A host with less memory
  # passes { name, digest, context } through the Rust runtime's environment;
  # null keeps Lucy's compiled defaults.
  model ? null,
}:
let
  rustPlatform = pkgs.makeRustPlatform {
    cargo = pkgs.rust-toolchain;
    rustc = pkgs.rust-toolchain;
  };
  cli = rustPlatform.buildRustPackage {
    pname = "lucy";
    version = "0.3.1-desktop";
    src = lucy;
    cargoLock = {
      lockFile = "${lucy}/Cargo.lock";
      outputHashes."nibli-engine-0.2.0" = "sha256-q9rG8QUlYPEcqu3oRqpIiAlJVyW+5x6eWqBCSNRIHjI=";
    };
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.gtk4 ];
    buildFeatures = [ "desktop-ui" ];
    cargoBuildFlags = [
      "-p"
      "lucy-cli"
    ];
    cargoTestFlags = [
      "-p"
      "lucy-cli"
    ];
  };
  desktopSource = "${lucy}/lucy-cli/desktop";
  modelWrapperArgs = lib.optionals (model != null) [
    "--set"
    "LUCY_CHAT_MODEL"
    model.name
    "--set"
    "LUCY_CHAT_DIGEST"
    model.digest
    "--set"
    "LUCY_CHAT_CONTEXT"
    (toString model.context)
  ];
  vsix = pkgs.runCommand "lucy-vscode-1.0.0.vsix" { nativeBuildInputs = [ pkgs.zip ]; } ''
    mkdir extension
    cp ${lucy}/lucy-cli/desktop/adapters/vscode/* extension/
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
    pkgs.vscode
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  name = "lucy-desktop";
  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.wrapGAppsHook4
  ];
  buildInputs = [ pkgs.gtk4 ];
  # One wrapper supplies both GTK resources and Lucy's packaged dependencies.
  dontWrapGApps = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/lucy"
    ln -s ${cli}/bin/lucy "$out/bin/lucy"
    cat > "$out/bin/lucy-native-host" <<EOF
    #!${pkgs.runtimeShell}
    exec "$out/bin/lucy" native-host
    EOF
    chmod +x "$out/bin/lucy-native-host"
    ln -s ${desktopSource}/adapters/browser "$out/share/lucy/browser-extension"
    ln -s ${vsix} "$out/share/lucy/lucy.vsix"
    ln -s ${inventory} "$out/share/lucy/integrations.json"
    runHook postInstall
  '';
  postFixup = ''
    wrapProgram "$out/bin/lucy" \
      "''${gappsWrapperArgs[@]}" \
      ${lib.escapeShellArgs modelWrapperArgs} \
      --set LUCY_EXECUTABLE "$out/bin/lucy" \
      --set LUCY_NATIVE_HOST "$out/bin/lucy-native-host" \
      --set LUCY_VSIX ${vsix} \
      --set LUCY_IDENTITY ${identity} \
      --set LUCY_INVENTORY ${inventory} \
      --set LUCY_INPUT_HELPER ${inputHelper} \
      --set LUCY_DMI_HELPER ${dmiHelper} \
      --set YDOTOOL_SOCKET /run/lucy-input/socket \
      --prefix PATH : ${lib.makeBinPath runtimePaths} \
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
  '';
  passthru = {
    inherit
      cli
      vsix
      desktopSource
      model
      ;
  };
}
