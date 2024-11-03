#! /usr/bin/bash
# Author: Massimo Di Pierro <massimo.dipierro@gmail.com>
# License: 3-clause BSD, https://opensource.org/license/bsd-3-clause

# install emacs if missing
which nix-shell || curl -k -L https://nixos.org/nix/install | sh -s -- $daemon
# make a temp nix shell config
cat <<\EOF > /tmp/shell.nix
let
  nixpkgs-src = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/tarball/nixos-24.05";
  };
  pkgs = import nixpkgs-src { config = { allowUnfree = true; }; };

  shell = pkgs.mkShell {
    buildInputs = [
      # development environment
      pkgs.qemacs
      pkgs.helix
      pkgs.openssh
      pkgs.zip
      pkgs.mc
      pkgs.git
      pkgs.ncdu
      pkgs.htop
      pkgs.tmux
      pkgs.dtach
      pkgs.cmake

      # python
      pkgs.python312
      pkgs.python312Packages.pip
      pkgs.python312Packages.setuptools
      pkgs.python312Packages.wheel
      pkgs.python312Packages.isort
      pkgs.python312Packages.black
      pkgs.python312Packages.pylint
      pkgs.python312Packages.pytest
      pkgs.python312Packages.twine

      # image tool
      pkgs.imagemagick

      # needed for compiling python libs
      pkgs.readline
      pkgs.libffi
      pkgs.openssl

      # chrome and vscode
      pkgs.ungoogled-chromium
      pkgs.vscode
      pkgs.vscode-extensions.bbenoist.nix
      pkgs.vscode-extensions.esbenp.prettier-vscode
      pkgs.vscode-extensions.eamodio.gitlens
      pkgs.vscode-extensions.ritwickdey.liveserver
      pkgs.vscode-extensions.ms-vscode-remote.remote-ssh
      pkgs.vscode-extensions.yzhang.markdown-all-in-one
    ];

    shellHook = ''
      # make a nice looking prompt and env
      myprompt() {
        export PS1="\e[30;48;5;214m\u@\h #$SHLVL \w [\$(git branch -q --show-current 2>/dev/null)]\e[0m\n$ "
        export NIX_SHELL_PRESERVE_PROMPT=1
        export SOURCE_DATE_EPOCH=$(date +%s)
        export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive
        export EDITOR=qe
        export GIT_EDITOR=qe
      }
      # make or use a venv in ~/.venv for the current dir
      venv() {
        VENV_PATH=/home/$USER/.venvs`pwd`/venv${pkgs.python311.version}
        if test ! -d $VENV_PATH; then
          python -m venv $VENV_PATH
        fi
        if [ -f requirements.txt ]; then
          $VENV_PATH/bin/pip install -U -r requirements.txt
        fi
        source $VENV_PATH/bin/activate
        export PYTHONPATH=$VENV_PATH/${pkgs.python311.sitePackages}/:$PYTHONPATH
      }
      # remove unwanted files
      cleanup() {
      	find ./ \( -name "*~" -o -name "#*" -o -name "*.pyc" \) -exec rm {} \;
      }
      # created a layerd fs in the current fir and optionally exec $@
      overlay() {
        A=$(pwd)
        B=/tmp/overlay-$(echo -n $A | sha1sum | head -c 16)
        rm -rf $B && mkdir $B && mkdir $B/w && mkdir $B/u
      	echo "trap 'rm -rf $B/w $B/s' EXIT && cd .. && mount -t overlay overlay -o lowerdir=$A,upperdir=$B/u,workdir=$B/w $A && cd $A && [ -z '$@' ] && unshare -U bash --init-file <(echo \"PS1='\e[0;31m[overlay]\e[m\w> '\") || (echo '$@' > $B/c && unshare -U bash $B/c)" >$B/s
        unshare -rm bash "$B/s"
      }
      # make the prompt
      myprompt
    '';
  };
in shell
EOF
# enter the nix shell
nix-shell /tmp/shell.nix
