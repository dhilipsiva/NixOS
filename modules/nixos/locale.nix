# Locale, timezone, console keymap and console colours. systemd-timesyncd is on by default.
{ ... }:

let
  quine = import ../../lib/quine.nix;
in
{
  time.timeZone = "Asia/Colombo";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  # QUINE's terminal colours from early boot on, for the TTYs and the greeter. The first
  # entry is the console's background, so it is the void rather than ANSI black. The
  # console draws backgrounds only from the first eight colours, so red is ember here too:
  # the greeter's ember keys need it.
  console.colors = [
    quine.palette.void900
    quine.palette.ember500
  ]
  ++ builtins.genList (i: builtins.elemAt quine.ansiList (i + 2)) 14;
}
