# The official release runtime includes the standalone Agent CLI and its TUI.
# Use the matching Node major and native modules; install no desktop service.
{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  esbuild,
  jq,
  makeWrapper,
  nodejs_22,
  zlib,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).zcode-cli;
  desktopResources = appimageTools.extract {
    pname = "zcode-resources";
    inherit (release) version;
    src = fetchurl {
      url = release.resourcesUrl;
      hash = release.resourcesHash;
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "zcode-cli";
  inherit (release) version;
  src = fetchurl {
    inherit (release) url hash;
  };
  nativeBuildInputs = [
    autoPatchelfHook
    esbuild
    jq
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];
  dontConfigure = true;
  dontStrip = true;
  buildPhase = ''
    runHook preBuild
    # The server release carries the TUI sources and production dependencies,
    # but omits dist/. Follow its scripts/build.mjs with Nix's esbuild.
    externals=()
    while IFS= read -r dependency; do
      externals+=("--external:$dependency")
    done < <(jq -r '.dependencies | keys[] | select(startswith("@zcode/") | not)' \
      runtime/node_modules/@zcode/tui/package.json)
    esbuild runtime/node_modules/@zcode/tui/src/index.ts \
      --outfile=runtime/node_modules/@zcode/tui/dist/index.js \
      --bundle --format=esm --platform=node --target=node22 --sourcemap \
      "''${externals[@]}"

    # These alternate libc bindings cannot load on this glibc-only platform.
    rm -rf runtime/node_modules/koffi/build/koffi/musl_x64
    rm -f runtime/node_modules/unsafe-pointer/prebuilds/linux-x64/unsafe-pointer.musl.node
    # Nix's Node 22 has the same native-module ABI as the bundled 22.16.0,
    # without relying on the upstream executable's non-Nix loader layout.
    rm runtime/node
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec/zcode"
    cp -r runtime/. "$out/libexec/zcode/"
    ln -s ${nodejs_22}/bin/node "$out/libexec/zcode/node"
    # Only the public provider catalogue is needed from the matching desktop
    # release. No Electron application or user credentials enter the closure.
    mkdir -p "$out/libexec/zcode/provider"
    cp ${desktopResources}/resources/config/provider/zcode-builtin.json \
      "$out/libexec/zcode/provider/zcode-builtin.json"
    makeWrapper "$out/libexec/zcode/node" "$out/bin/zcode" \
      --add-flags "$out/libexec/zcode/zcode.cjs"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export ZCODE_DATA_BASE_DIR="$TMPDIR/zcode-check"
    "$out/bin/zcode" --version
    "$out/bin/zcode" --help > /dev/null
    "$out/libexec/zcode/node" --input-type=module -e \
      'await import("'"$out"'/libexec/zcode/node_modules/@zcode/tui/dist/index.js")'
    runHook postInstallCheck
  '';
  meta = {
    description = "Z.ai coding agent with an interactive terminal interface";
    homepage = "https://github.com/zai-org/ZCode";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zcode";
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
      fromSource
    ];
  };
}
