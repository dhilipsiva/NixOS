# Official stable release, pinned by the digest published with the GitHub asset.
{ lib, stdenv, fetchurl, autoPatchelfHook, installShellFiles }:

let release = (builtins.fromJSON (builtins.readFile ./releases.json)).herdr;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr";
  inherit (release) version;
  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${finalAttrs.version}/herdr-linux-x86_64";
    inherit (release) hash;
  };
  nativeBuildInputs = [ autoPatchelfHook installShellFiles ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/herdr
    runHook postInstall
  '';
  postFixup = ''
    installShellCompletion --cmd herdr \
      --bash <($out/bin/herdr completion bash) \
      --fish <($out/bin/herdr completion fish) \
      --zsh <($out/bin/herdr completion zsh)
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/herdr --version | grep -F '${finalAttrs.version}'
  '';
  meta = {
    description = "Terminal multiplexer for coding agents";
    homepage = "https://herdr.dev";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "herdr";
  };
})
