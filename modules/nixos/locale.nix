# Locale, timezone, and console keymap. systemd-timesyncd is on by default.
{ ... }:

{
  time.timeZone = "Asia/Colombo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
}
