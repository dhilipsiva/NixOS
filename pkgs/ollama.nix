# Official stable CPU/CUDA distribution while Nixpkgs trails upstream. Keep the
# release and checksum together; do not substitute an unpinned 'latest' URL.
{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, zstd, zlib, vulkan-loader, ... }:

let release = (builtins.fromJSON (builtins.readFile ./releases.json)).ollama;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "ollama";
  inherit (release) version;
  src = fetchurl {
    url = "https://github.com/ollama/ollama/releases/download/v${finalAttrs.version}/ollama-linux-amd64.tar.zst";
    inherit (release) hash;
  };
  nativeBuildInputs = [ autoPatchelfHook makeWrapper zstd ];
  buildInputs = [ stdenv.cc.cc.lib zlib vulkan-loader ];
  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;
  # The host's NVIDIA driver provides this library at activation/runtime.
  autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin lib $out/
    runHook postInstall
  '';
  postFixup = ''
    wrapProgram $out/bin/ollama \
      --suffix LD_LIBRARY_PATH : /run/opengl-driver/lib
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/ollama --version 2>&1 | grep -F '${finalAttrs.version}'
    test -n "$(find $out/lib/ollama -name 'libggml-cuda.so*' -print -quit)"
  '';
  meta = {
    description = "Local model inference with upstream CPU and CUDA runners";
    homepage = "https://ollama.com";
    license = [ lib.licenses.mit lib.licenses.unfree ]; # bundled NVIDIA runtimes
    platforms = [ "x86_64-linux" ];
    mainProgram = "ollama";
  };
})
