# Identity and compatibility anchors read on the installed Yoga on 2026-10-04.
# The owner installed NixOS 26.05 (26.05.11150.825e2028c29b) with the official
# graphical installer, so both anchors start at that release. Never change them
# without a documented data migration.
{ ... }:

{
  repo.maintenance.boardName = "LNVNB161216";
  system.stateVersion = "26.05";
  home-manager.users.dhilipsiva.home.stateVersion = "26.05";
}
