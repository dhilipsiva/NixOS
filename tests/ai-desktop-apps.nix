{
  lib,
  pkgs,
  hosts,
}:
let
  inherit (pkgs) chatgpt claude-desktop;
  inherit (claude-desktop) cowork;
  configured =
    host:
    let
      config = host.config;
      names = map lib.getName config.home-manager.users.dhilipsiva.home.packages;
    in
    builtins.all (name: builtins.elem name names) [
      "chatgpt"
      "claude-desktop"
      "codex"
      "claude-code"
    ]
    && builtins.elem "vhost_vsock" config.boot.kernelModules
    && builtins.elem "kvm" config.users.users.dhilipsiva.extraGroups
    && config.programs.nix-ld.enable
    && config.services.gnome.gnome-keyring.enable
    && builtins.any (
      rule: lib.hasPrefix "L+ /usr/libexec/virtiofsd " rule
    ) config.systemd.tmpfiles.rules;
in
assert lib.assertMsg (builtins.all configured (
  builtins.attrValues hosts
)) "All hosts must include both desktop apps, their existing CLIs, and Cowork prerequisites.";
pkgs.runCommand "ai-desktop-apps-check"
  {
    nativeBuildInputs = [ pkgs.desktop-file-utils ];
  }
  ''
    for app in ${chatgpt} ${claude-desktop}; do
      for entry in "$app"/share/applications/*.desktop; do
        desktop-file-validate "$entry"
      done
    done
    test -s ${chatgpt}/share/pixmaps/chatgpt.png
    test -s ${claude-desktop}/share/icons/hicolor/256x256/apps/claude-desktop.png
    grep -q 'x-scheme-handler/codex;' ${chatgpt}/share/applications/chatgpt.desktop
    grep -q 'x-scheme-handler/claude;' ${claude-desktop}/share/applications/com.anthropic.Claude.desktop
    test -x ${chatgpt}/bin/chatgpt
    test -x ${claude-desktop}/bin/claude-desktop
    test -s ${cowork.firmware}/FV/OVMF_CODE.fd
    test -s ${cowork.firmware}/FV/OVMF_VARS.fd
    ${cowork.qemu_kvm}/bin/qemu-system-x86_64 --version
    ${cowork.virtiofsd}/bin/virtiofsd --version
    touch "$out"
  ''
