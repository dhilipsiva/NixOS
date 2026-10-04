# Cleanup policy

The repository holds only what the three machines need: the flake, shared NixOS
and Home Manager modules, per-host hardware and policy, pinned release metadata,
the deployment tooling with its tests, encrypted secrets and the operating
documents. Removed over time: the reinstall plans, the inactive partitioning
module, superseded shell scripts, the raw dotfile tree (Zellij's KDL was the last
file; its content was the old upstream default keybindings) and template noise in
`.gitignore`. History stays in Git. `misc/` and `signature.html` are unrelated
personal assets that the owner keeps deliberately.

`nixosctl cleanup` and the 22:00 GC timer stay gated on each host's accepted
first verified boot and physical checks. They delete unused Nix store paths and
Nix-managed generations older than 30 days under a common lock that excludes
deployments. The original system and home-profile roots are retained. The
desktop's signed recovery image survives its five-entry rotation; the ThinkPad's
original kernel/initrd and encrypted-root entry survive its three-entry rotation
without changing its existing unsigned boot policy. The Yoga's original GNOME
generation 1 is its protected recovery root, and its unused installer swap
partition is not a cleanup target. Those recovery roots are
deliberately not aged out; remove them only after a separate recovery review.

No cleanup of models, project caches, browser profiles, personal files or Windows
data is performed. Home Manager moves colliding regular files into unique sibling
backup directories and never overwrites a prior backup. ESP/trust backups remain
root-only under /var/lib/nixos-deployment; copy them to offline storage before
firmware changes. Journald, `/var/tmp` (30 days) and the in-memory `/tmp` are
bounded by the policies in `modules/nixos/nix.nix`.

The ThinkPad's private application-migration backup under
`~/.local/state/nixosctl/home-migration/`, its original `~/.files/.config` tree,
Sober data and OBS recordings are not cleanup targets. Preserve them for recovery.

Review /var/lib/nixos-deployment and ~/.local/state/nixosctl/builds periodically;
no blind home-directory or backup pruning is scheduled. Rootless Docker keeps its
images under the user's home, outside every cleanup path.
