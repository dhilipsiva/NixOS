# Upstream stable release bridge until Nixpkgs catches up. The musl build is
# self-contained; the checksum is the upstream GitHub release asset digest.
{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  ...
}:

let
  release = (builtins.fromJSON (builtins.readFile ./releases.json)).atuin;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "atuin";
  inherit (release) version;
  src = fetchurl {
    url = "https://github.com/atuinsh/atuin/releases/download/v${finalAttrs.version}/atuin-x86_64-unknown-linux-musl.tar.gz";
    inherit (release) hash;
  };
  nativeBuildInputs = [ installShellFiles ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 atuin $out/bin/atuin
    installShellCompletion --cmd atuin \
      --bash <($out/bin/atuin gen-completions -s bash) \
      --fish <($out/bin/atuin gen-completions -s fish) \
      --zsh <($out/bin/atuin gen-completions -s zsh)
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/atuin --version | grep -F '${finalAttrs.version}'
  '';
  meta = {
    description = "Shell history with context and encrypted synchronization";
    homepage = "https://atuin.sh";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "atuin";
  };
})
