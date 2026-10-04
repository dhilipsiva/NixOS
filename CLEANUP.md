# Cleanup policy

Removed the obsolete reinstall plans, inactive disko module, superseded disk and
notification scripts, and unused raw dotfiles. The active Zellij KDL, SESSION.md,
LICENSE and unrelated misc/signature assets remain. History stays in Git.

`nixosctl cleanup` and the 22:00 GC timer remain blocked until the first verified
boot and physical checks are accepted. They delete unused Nix store paths and Nix-managed generations
older than 30 days. A common lock prevents collection during deployment.
The original system and home-profile roots are retained. The desktop's signed
recovery image survives its normal five-entry rotation; the ThinkPad's original
kernel/initrd and encrypted-root entry survive its three-entry rotation without
changing its existing unsigned boot policy. Those recovery roots
are deliberately not aged out; remove them only after a separate recovery review.

No cleanup of models, project caches, browser profiles, personal files or Windows
data is performed. Home Manager moves colliding regular files into unique sibling
backup directories. It never overwrites a prior backup. ESP/trust backups remain
root-only under /var/lib/nixos-deployment; copy them to offline storage before
firmware changes. The existing tmpfiles/log rotation policies remain bounded.

The ThinkPad's private application-migration backup under
`~/.local/state/nixosctl/home-migration/`, its original `~/.files/.config` tree,
Sober data and OBS recordings are not cleanup targets. Preserve them for recovery.

After acceptance, run `scripts/nixosctl cleanup` for the approved one-time
collection. Review /var/lib/nixos-deployment and ~/.local/state/nixosctl/builds
periodically; no blind home-directory or backup pruning is scheduled.
