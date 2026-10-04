# The pinned official archive includes lib/ollama/vulkan/libggml-vulkan.so.
# Keep this separate from the existing desktop/ThinkPad CUDA package.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  zstd,
  zlib,
  vulkan-loader,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).ollama;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ollama-vulkan";
  inherit (release) version;
  src = fetchurl {
    url = "https://github.com/ollama/ollama/releases/download/v${finalAttrs.version}/ollama-linux-amd64.tar.zst";
    inherit (release) hash;
  };
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    zstd
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    vulkan-loader
  ];
  unpackPhase = ''
    tar --zstd -xf $src --exclude='lib/ollama/cuda*' --exclude='lib/ollama/rocm*'
  '';
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    mkdir -p $out
    cp -r bin lib $out/
  '';
  postFixup = ''
    wrapProgram $out/bin/ollama --suffix LD_LIBRARY_PATH : /run/opengl-driver/lib
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/ollama --version 2>&1 | grep -F '${finalAttrs.version}'
    test -f $out/lib/ollama/vulkan/libggml-vulkan.so
    test -z "$(find $out -iname '*cuda*' -o -iname '*rocm*')"
  '';
  meta = {
    description = "Ollama with the verified upstream Vulkan runner";
    homepage = "https://ollama.com";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ollama";
  };
})
