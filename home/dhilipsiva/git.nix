# Git — ported from .config/git/config + .config/git/excludesfile.
{ ... }:

{
  programs.git = {
    enable = true;

    # excludesfile -> home-manager writes these and sets core.excludesFile.
    ignores = [
      # Compiled source
      "*.com" "*.class" "*.dll" "*.exe" "*.o" "*.so"
      # Packages
      "*.7z" "*.dmg" "*.gz" "*.iso" "*.jar" "*.rar" "*.tar" "*.zip"
      # Logs and databases
      "*.log" "*.sql" "*.sqlite"
      # OS generated files
      ".DS_Store" ".DS_Store?" "._*" ".Spotlight-V100" ".Trashes" "ehthumbs.db" "Thumbs.db"
      ".sass-cache/" "*.swp" "*.swo" "*.pyc"
      # Custom files
      "db.sqlite3" ".vagrant/" "node_modules/" "no-git-conf/" ".ropeproject/" "dump.rdb"
    ];

    # Everything else -> the freeform git config (settings; toGitINI).
    settings = {
      user = {
        name = "dhilipsiva";
        email = "dhilipsiva@pm.me";
      };
      branch.autosetuprebase = "always";
      github.user = "dhilipsiva";
      diff.external = "difft"; # difftastic (in packages.nix)

      alias = {
        l = "log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %C(bold blue)<%an>%Creset' -n 40 --graph --abbrev-commit";
        s = "status -s";
        a = "add";
        f = "fetch";
        d = "diff";
        pl = "pull --rebase";
        p = "push";
        sy = "!git pull && git push";
        pt = "push --tags";
        cl = "clone --recursive";
        c = "commit";
        ca = "!git add -A && git commit -av";
        t = "tag -s";
        co = "checkout";
        tags = "tag -l";
        branches = "branch -a";
        remotes = "remote -v";
        credit = "!f() { git commit --amend --author \"$1 <$2>\" -C HEAD; }; f";
        reb = "!r() { git rebase -i HEAD~$1; }; r";
        fb = "!f() { git branch -a --contains $1; }; f";
        ft = "!f() { git describe --always --contains $1; }; f";
        fc = "!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short -S$1; }; f";
        fm = "!f() { git log --pretty=format:'%C(yellow)%h  %Cblue%ad  %Creset%s%Cgreen  [%cn] %Cred%d' --decorate --date=short --grep=$1; }; f";
        dm = "!git branch --merged | grep -v '\\*' | xargs -n 1 git branch -d";
        b = "branch";
        # Smart quotes preserved verbatim from the original.
        it = "!git init && git commit -m “Initial Commit” --allow-empty";
        st = "stash";
        stsh = "stash --keep-index";
        staash = "stash --include-untracked";
        staaash = "stash --all";
        please = "push --force-with-lease";
        o = "open";
        mr = "!sh -c 'git fetch $1 merge-requests/$2/head:mr-$1-$2 && git checkout mr-$1-$2' -";
      };

      apply.whitespace = "fix";
      core = {
        whitespace = "space-before-tab,-indent-with-non-tab,trailing-space";
        trustctime = false;
      };
      color = {
        ui = "auto";
        branch = { current = "yellow reverse"; local = "yellow"; remote = "green"; };
        diff = { meta = "yellow bold"; frag = "magenta bold"; old = "red bold"; new = "green bold"; };
        status = { added = "yellow"; changed = "green"; untracked = "cyan"; };
      };
      merge = { log = true; tool = "vimdiff"; };
      push.default = "matching";
      rebase.autosquash = true;
      credential.helper = "store";
      http.sslVerify = true;
      init.defaultBranch = "main";
    };
  };
}
