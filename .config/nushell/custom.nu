alias e = hx
alias g = git  # replace built-in `g` (it does [g]oto shell when used with `enter`)
alias l = lsd
alias q = exit
alias ze = zellij


# source ~/.cache/starship/init.nu
source ~/.zoxide.nu

$env.PATH = ($env.PATH | append "/home/dhilipsiva/.surrealdb")
$env.PATH = ("/home/dhilipsiva/.local/bin" | append $env.PATH)
