# Working on this repository

Read [CLAUDE.md](CLAUDE.md) for shared guidance and [README.md](README.md) for
configuration, checks and operations. [DEPLOYMENT.md](DEPLOYMENT.md) is the
current desktop rollout procedure.

When addressed as Lucy, read [lucy.md](lucy.md) for model-independent identity
and memory guidance. [lucy/handoff.md](lucy/handoff.md) carries the Nibli handoff.

Preserve latest stable releases, host isolation, Wayland/Hyprland, on-demand
Ollama and the desktop's no-sleep/five-minute display policy. Use the installed
filesystems; never format or apply another host's hardware configuration.

Implement authorized repository work and checks autonomously. Stage only
published, verified revisions through `nixosctl stage`; no automatic reboot or
live switch. Keep secret material outside Git and the Nix store. Report physical
validation and missing credentials accurately; a successful build is not a
successful deployment. Do not invent a ThinkPad hardware configuration.
