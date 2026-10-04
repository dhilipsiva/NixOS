{ pkgs, ... }:
{
  services.flatpak.enable = true;
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio.override { cudaSupport = false; };
  };
  home-manager.users.dhilipsiva = { lib, ... }: {
    home.packages = with pkgs; [
      npu-smoke
      libva-utils
      clinfo
      intel-gpu-tools
    ];
    xdg.desktopEntries.roblox-sober = {
      name = "Roblox (Sober)";
      comment = "Play Roblox using Sober";
      exec = "${pkgs.flatpak}/bin/flatpak run org.vinegarhq.Sober %u";
      icon = "org.vinegarhq.Sober";
      terminal = false;
      categories = [ "Game" ];
      settings.Keywords = "Roblox;Sober;";
    };
    # Seed a writable recording profile once. OBS retains subsequent user edits.
    home.activation.seedYogaObs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      profile="$HOME/.config/obs-studio/basic/profiles/Yoga"
      if [ ! -e "$profile" ]; then
        run mkdir -p "$profile"
        run cp ${./obs-basic.ini} "$profile/basic.ini"
        run cp ${./obs-recording.json} "$profile/recordEncoder.json"
        run chmod u+w "$profile/basic.ini" "$profile/recordEncoder.json"
      fi
    '';
  };
}
