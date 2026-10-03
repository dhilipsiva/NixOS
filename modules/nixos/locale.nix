# Locale, timezone, and console keymap.
{ ... }:

{
  time.timeZone = "Asia/Colombo";
  services.timesyncd.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
