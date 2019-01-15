from os import environ

from fabric.api import run, env, sudo, task, cd, settings
from gitric.api import git_seed, git_reset, allow_dirty

from fabtools import deb, require

env.user = environ['DOTFILES_USER']
env.hosts = environ['DOTFILES_HOST']
allow_dirty = allow_dirty  # Silence flake8

home_dir = "/home/%s" % env.user
tmp_dir = "%s/tmp" % home_dir
dot_dir = "%s/.files" % home_dir


@task
def echo():
    run("echo foo")


def wget(cmd):
    run("wget %s" % cmd)


@task
def setup_gui():
    run("/usr/lib/apt/apt-helper download-file http://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2017.01.02_all.deb keyring.deb SHA256:4c3c6685b1181d83efe3a479c5ae38a2a44e23add55e16a328b8c8560bf05e5f") # NOQA
    sudo("dpkg -i ./keyring.deb")
    sudo('echo "deb http://debian.sur5r.net/i3/ $(grep \'^DISTRIB_CODENAME=\' /etc/lsb-release | cut -f2 -d=) universe" >> /etc/apt/sources.list.d/sur5r-i3.list')  # NOQA
    deb.update_index()
    deb.upgrade()
    require.deb.packages(["i3", "nodm", "xfce4-terminal"])


@task
def setup():
    deb.update_index()
    deb.upgrade()
    require.deb.packages([
        "build-essential", "i3", "python-pip", "unzip", "xclip", "curl", "git",
        "iw", "network-manager", "firmware-atheros", "xfce4-terminal"])
    run('sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"')  # NOQA
    sudo("pip install -U pip")
    run("touch private.sh")
    git_seed(dot_dir)
    git_reset(dot_dir)
    with cd(dot_dir):
        with settings(warn_only=True):
            run("cp home/.* ~")
            run("cp -R fonts/ ~/.fonts")
    run("brew install gcc ruby curl python3 neovim bash bash-completion@2 git pipenv tmux")  # NOQA
    run("pip3 install powerline-shell pwdman hostscli neovim tmuxp")
    sudo("hostscli block_all")
    run("curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim") # NOQA
    run('nvim -c "PlugInstall | q | q"')

'''
Some Use commands for new machine
su -
ip link list
ip link set enp0s20f0u3 up
nmcli dev
nmcli dev list
nmcli device wifi rescan
lspci
apt install i3
vi /etc/apt/sources.list
apt install iw
apt install network-manager
iw config
exit
apt install firmware-atheros
'''
