{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
}:
let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).uv;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "uv";
  inherit (release) version;
  src = fetchurl {
    url = "https://github.com/astral-sh/uv/releases/download/${finalAttrs.version}/uv-x86_64-unknown-linux-musl.tar.gz";
    inherit (release) hash;
  };
  nativeBuildInputs = [ installShellFiles ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 uv $out/bin/uv
    install -Dm755 uvx $out/bin/uvx
    installShellCompletion --cmd uv \
      --bash <($out/bin/uv generate-shell-completion bash) \
      --fish <($out/bin/uv generate-shell-completion fish) \
      --zsh <($out/bin/uv generate-shell-completion zsh)
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = "$out/bin/uv --version | grep -F '${finalAttrs.version}' ";
  meta = {
    description = "Python package and project manager";
    homepage = "https://docs.astral.sh/uv/";
    license = with lib.licenses; [
      asl20
      mit
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "uv";
  };
})
