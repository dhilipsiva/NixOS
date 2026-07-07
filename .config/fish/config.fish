if status is-interactive
    # Commands to run in interactive sessions can go here
    atuin init fish | source
    # fnm env | source
    export PATH="/home/dhilipsiva/.cargo/bin":$PATH
end
