{
  writeShellApplication,
  python3,
  git,
  openssh,
  coreutils,
  libnotify,
}:
writeShellApplication {
  name = "lucy-backup";
  runtimeInputs = [
    python3
    git
    openssh
    coreutils
    libnotify
  ];
  text = ''
    export PYTHONDONTWRITEBYTECODE=1
    exec python3 ${../scripts/lucy-backup.py} "$@"
  '';
  meta.description = "Back up Lucy's private memory into its private Git repository";
}
