sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --no-daemon
curl -LsSf https://astral.sh/uv/install.sh | sh
nix-channel --update
export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ALLOW_BROKEN=1
echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
nix-env -iA \
    nixpkgs.glibcLocales \
    nixpkgs.helix \
    nixpkgs.qemacs \
    nixpkgs.jed \
    nixpkgs.openssh \
    nixpkgs.zip \
    nixpkgs.gzip \
    nixpkgs.gnutar \
    nixpkgs.mc \
    nixpkgs.git \
    nixpkgs.git-lfs \
    nixpkgs.ncdu \
    nixpkgs.htop \
    nixpkgs.tmux \
    nixpkgs.dtach \
    nixpkgs.cmake \
    nixpkgs.rsync \
    nixpkgs.sshfs \
    nixpkgs.gocryptfs \
    nixpkgs.python312 \
    nixpkgs.python312Packages.pip \
    nixpkgs.python312Packages.setuptools \
    nixpkgs.python312Packages.wheel \
    nixpkgs.imagemagick \
    nixpkgs.masterpdfeditor4 \
    nixpkgs.readline \
    nixpkgs.libffi \
    nixpkgs.openssl \
    nixpkgs.ungoogled-chromium \
    nixpkgs.vscode \
    nixpkgs.vscode-extensions.bbenoist.nix \
    nixpkgs.vscode-extensions.esbenp.prettier-vscode \
    nixpkgs.vscode-extensions.eamodio.gitlens \
    nixpkgs.vscode-extensions.ritwickdey.liveserver \
    nixpkgs.vscode-extensions.ms-vscode-remote.remote-ssh \
    nixpkgs.vscode-extensions.yzhang.markdown-all-in-one

# export EDITOR=qe
# export GIT_EDITOR=qe
# export PS1="\e[30;48;5;214m\u@\h #$SHLVL \w [\$(git branch -q --show-current 2>/dev/null)]\e[0m\n$ "

