# GTK and Qt apps in QUINE, the site's design system (lib/quine.nix): the void for
# surfaces, warm white text, ember as the single accent, IBM Plex for type.
{ pkgs, ... }:

let
  quine = import ../../lib/quine.nix;
  inherit (quine) palette font hex;

  # libadwaita and adw-gtk3 read these named colours; libadwaita 1.6 and later also
  # reads the CSS variables. Only colours: app stylesheets keep their own rules.
  gtkColours = with palette; {
    accent_color = ember300;
    accent_bg_color = ember500;
    accent_fg_color = onEmber;
    destructive_color = crimson;
    destructive_bg_color = crimson;
    destructive_fg_color = paper100;
    success_color = phosphor500;
    success_bg_color = phosphor700;
    success_fg_color = void1000;
    warning_color = amber;
    warning_bg_color = amber;
    warning_fg_color = void1000;
    error_color = crimson;
    error_bg_color = crimson;
    error_fg_color = paper100;
    window_bg_color = void900;
    window_fg_color = paper100;
    view_bg_color = void800;
    view_fg_color = paper200;
    headerbar_bg_color = void900;
    headerbar_fg_color = paper100;
    headerbar_border_color = void500;
    headerbar_backdrop_color = void900;
    sidebar_bg_color = void800;
    sidebar_fg_color = paper200;
    sidebar_backdrop_color = void800;
    card_bg_color = void700;
    card_fg_color = paper200;
    dialog_bg_color = void800;
    dialog_fg_color = paper100;
    popover_bg_color = void700;
    popover_fg_color = paper100;
    thumbnail_bg_color = void700;
    thumbnail_fg_color = paper200;
  };
  defines = builtins.concatStringsSep "\n" (
    map (name: "@define-color ${name} ${hex gtkColours.${name}};") (builtins.attrNames gtkColours)
  );
  variables = builtins.concatStringsSep "\n" (
    map (name: "  --${builtins.replaceStrings [ "_" ] [ "-" ] name}: ${hex gtkColours.${name}};") (
      builtins.attrNames gtkColours
    )
  );

  # KDE colour groups for Dolphin and other Qt apps (platform theme "kde").
  kdeGroup =
    with palette;
    {
      background,
      alternate,
      foreground,
      inactive ? muted,
    }:
    {
      BackgroundNormal = quine.kde background;
      BackgroundAlternate = quine.kde alternate;
      ForegroundNormal = quine.kde foreground;
      ForegroundInactive = quine.kde inactive;
      ForegroundActive = quine.kde ember300;
      ForegroundLink = quine.kde ember300;
      ForegroundVisited = quine.kde quanta300;
      ForegroundNegative = quine.kde crimson;
      ForegroundNeutral = quine.kde amber;
      ForegroundPositive = quine.kde phosphor500;
      DecorationFocus = quine.kde ember500;
      DecorationHover = quine.kde ember300;
    };
in
{
  gtk = {
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      # Folders in the deep orange closest to ember.
      package = pkgs.papirus-icon-theme.override { color = "deeporange"; };
    };
    font = {
      name = font.sans;
      size = 11;
    };
    # Dark, as QUINE is. Not `gtk.colorScheme`: Home Manager writes GTK 4's
    # gtk-interface-color-scheme as a number, which GTK 4.22 rejects; it takes the name.
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-interface-color-scheme = "dark";
    };
    gtk3.extraCss = defines;
    gtk4.extraCss = ''
      ${defines}
      :root {
      ${variables}
      }
    '';
  };

  dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "Papirus-Dark";
    font-name = "${font.sans} 11";
    document-font-name = "${font.sans} 11";
    monospace-font-name = "${font.mono} 11";
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
    # Written with kwriteconfig6 at activation, so kdeglobals stays a normal file that
    # KDE apps can still write to.
    kde.settings.kdeglobals = with palette; {
      General = {
        ColorScheme = "Quine";
        font = "${font.sans},10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        fixed = "${font.mono},10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        smallestReadableFont = "${font.sans},8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        toolBarFont = "${font.sans},10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        menuFont = "${font.sans},10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      };
      Icons.Theme = "Papirus-Dark";
      KDE.widgetStyle = "Breeze";
      "Colors:View" = kdeGroup {
        background = void800;
        alternate = void700;
        foreground = paper200;
      };
      "Colors:Window" = kdeGroup {
        background = void900;
        alternate = void800;
        foreground = paper100;
      };
      "Colors:Button" = kdeGroup {
        background = void700;
        alternate = void600;
        foreground = paper100;
      };
      "Colors:Selection" = kdeGroup {
        background = ember500;
        alternate = ember600;
        foreground = onEmber;
        inactive = onEmber;
      };
      "Colors:Tooltip" = kdeGroup {
        background = void700;
        alternate = void600;
        foreground = paper100;
      };
      "Colors:Complementary" = kdeGroup {
        background = void1000;
        alternate = void900;
        foreground = paper100;
      };
      "Colors:Header" =
        kdeGroup {
          background = void900;
          alternate = void800;
          foreground = paper100;
        }
        // {
          Inactive = kdeGroup {
            background = void900;
            alternate = void800;
            foreground = muted;
          };
        };
      WM = {
        activeBackground = quine.kde void900;
        activeForeground = quine.kde paper100;
        inactiveBackground = quine.kde void900;
        inactiveForeground = quine.kde muted;
        activeBlend = quine.kde ember500;
        inactiveBlend = quine.kde void500;
      };
    };
  };
}
