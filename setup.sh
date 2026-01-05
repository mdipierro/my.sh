sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
curl -LsSf https://astral.sh/uv/install.sh | sh
# nix-channel --update
export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ALLOW_BROKEN=1
mkdir -p $HOME/.config/nix/nix.conf
echo "experimental-features = nix-command flakes" > $HOME/.config/nix/nix.conf
nix-env -iA nixpkgs.glibcLocales
nix-env -iA nixpkgs.helix
nix-env -iA nixpkgs.qemacs
nix-env -iA nixpkgs.jed
nix-env -iA nixpkgs.openssh
nix-env -iA nixpkgs.zip
nix-env -iA nixpkgs.gzip
nix-env -iA nixpkgs.gnutar
nix-env -iA nixpkgs.git
nix-env -iA nixpkgs.git-lfs
nix-env -iA nixpkgs.ncdu
nix-env -iA nixpkgs.fzf
nix-env -iA nixpkgs.lf
nix-env -iA nixpkgs.mc
nix-env -iA nixpkgs.btop
nix-env -iA nixpkgs.bat
nix-env -iA nixpkgs.tmux
nix-env -iA nixpkgs.dtach
nix-env -iA nixpkgs.cmake
nix-env -iA nixpkgs.rsync
nix-env -iA nixpkgs.sshfs
nix-env -iA nixpkgs.ripgrep
nix-env -iA nixpkgs.gocryptfs
nix-env -iA nixpkgs.python312
nix-env -iA nixpkgs.python312Packages.pip
nix-env -iA nixpkgs.python312Packages.setuptools
nix-env -iA nixpkgs.python312Packages.wheel
nix-env -iA nixpkgs.imagemagick
nix-env -iA nixpkgs.readline
nix-env -iA nixpkgs.libffi
nix-env -iA nixpkgs.openssl
nix-env -iA nixpkgs.masterpdfeditor4    
nix-env -iA nixpkgs.maestral
nix-env -iA nixpkgs.aichat
nix-env -iA nixpkgs.ollama
nix-env -iA nixpkgs.llama-cpp
nix-env -iA nixpkgs.vscode
nix-env -iA nixpkgs.vscode-extensions.bbenoist.nix
nix-env -iA nixpkgs.vscode-extensions.esbenp.prettier-vscode
nix-env -iA nixpkgs.vscode-extensions.eamodio.gitlens
nix-env -iA nixpkgs.vscode-extensions.ritwickdey.liveserver
nix-env -iA nixpkgs.vscode-extensions.ms-vscode-remote.remote-ssh
nix-env -iA nixpkgs.vscode-extensions.yzhang.markdown-all-in-one
nix-env -iA nixpkgs.brave

# export EDITOR=qe
# export GIT_EDITOR=qe
# export NIX_SHELL_PRESERVE_PROMPT=1
# export PS1="\e[30;48;5;214m\u@\h #$SHLVL \w [\$(git branch -q --show-current 2>/dev/null)]\e[0m\n$ "
