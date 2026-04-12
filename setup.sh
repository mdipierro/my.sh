#!/usr/bin/env bash
# setup.sh — bootstrap Nix, home-manager, and write the declarative config.
#
# This is the single source of truth. Running it:
#   1. Installs Nix (if missing)
#   2. Installs uv (if missing)
#   3. Writes ~/.config/home-manager/{flake.nix,home.nix}
#   4. Applies home-manager (installs Node.js and all other packages)
#   5. Installs Claude Code via npm (if missing)
#   4. Applies the config via `home-manager switch`
#
# After the first run, day-to-day changes are made by editing this file and
# re-running it, OR by editing ~/.config/home-manager/home.nix directly and
# running: home-manager switch --flake ~/.config/home-manager#$(whoami)
#
# Useful home-manager commands:
#   home-manager generations                    # list all generations
#   home-manager switch --switch-generation <N> # roll back
#   nix-collect-garbage -d                      # free disk space
set -euo pipefail

USER="${USER:-$(whoami)}"
HOME_MANAGER_DIR="$HOME/.config/home-manager"

# ---------------------------------------------------------------------------
# 1. Install Nix (multi-user / daemon mode)
#    Skipped if nix is already on PATH.
# ---------------------------------------------------------------------------
if ! command -v nix &>/dev/null; then
  echo ">>> Installing Nix..."
  sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
else
  echo ">>> Nix already installed, skipping."
fi

# ---------------------------------------------------------------------------
# 2. Enable flakes and the new nix CLI
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi

# ---------------------------------------------------------------------------
# 3. Install uv (fast Python package/project manager)
#    Kept outside Nix because uv manages its own Python toolchain.
# ---------------------------------------------------------------------------
if ! command -v uv &>/dev/null; then
  echo ">>> Installing uv..."
  # --no-modify-path: skip patching ~/.profile / ~/.bashrc / ~/.bash_profile.
  # Those files are managed by home-manager (and may be read-only at this
  # point). ~/.local/bin is already added to PATH by home-manager's
  # sessionVariables, so no manual PATH patching is needed.
  curl -LsSf https://astral.sh/uv/install.sh | sh -s -- --no-modify-path
else
  echo ">>> uv already installed, skipping."
fi


# ---------------------------------------------------------------------------
# 4. Write flake.nix
#    Entry point for home-manager. Pins nixpkgs and home-manager as inputs.
#    To update inputs to their latest versions: nix flake update
# ---------------------------------------------------------------------------
mkdir -p "$HOME_MANAGER_DIR"
echo ">>> Writing $HOME_MANAGER_DIR/flake.nix..."
cat > "$HOME_MANAGER_DIR/flake.nix" << 'EOF'
{
  description = "Personal home-manager configuration";

  inputs = {
    # Rolling unstable channel — packages stay current.
    # Pin to a specific rev for reproducibility across machines, e.g.:
    #   nixpkgs.url = "github:nixos/nixpkgs/abc123";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Ensure home-manager uses the same nixpkgs as above.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      # Add "aarch64-darwin" here for Apple Silicon, "x86_64-darwin" for Intel Mac.
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;   # needed for vscode, masterpdfeditor4, brave
          allowBroken = true;
        };
      };
    in
    {
      # To support multiple machines, add entries here, e.g.:
      #   "alice@aarch64-darwin" = home-manager.lib.homeManagerConfiguration { ... };
      homeConfigurations."__USER__" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
EOF
# Substitute the actual username (can't use shell variables inside 'EOF' heredoc)
sed -i "s/__USER__/$USER/g" "$HOME_MANAGER_DIR/flake.nix"

# ---------------------------------------------------------------------------
# 5. Write home.nix
#    Declarative user environment: packages, shell, editor, prompt.
#    To find a package name: https://search.nixos.org/packages
# ---------------------------------------------------------------------------
echo ">>> Writing $HOME_MANAGER_DIR/home.nix..."
cat > "$HOME_MANAGER_DIR/home.nix" << 'EOF'
{ pkgs, ... }:
{
  # ---------------------------------------------------------------------------
  # Identity
  # ---------------------------------------------------------------------------
  home.username = "__USER__";
  home.homeDirectory = "__HOME__";

  # Matches the home-manager release. Do not change after first switch.
  home.stateVersion = "24.11";

  # Let home-manager manage itself.
  programs.home-manager.enable = true;

  # ---------------------------------------------------------------------------
  # Packages
  # To find a package name: https://search.nixos.org/packages
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [

    # --- Locale ---------------------------------------------------------------
    glibcLocales          # prevents "locale: cannot set LC_ALL" warnings

    # --- Editors --------------------------------------------------------------
    helix                 # modal editor (hx)
    qemacs                # lightweight emacs-compatible editor
    jed                   # small emacs-like editor, good for remote/low-resource

    # --- Shell utilities ------------------------------------------------------
    fzf                   # fuzzy finder — integrates with many shell tools
    bat                   # cat with syntax highlighting
    ripgrep               # fast grep (rg)
    ncdu                  # interactive disk usage viewer
    btop                  # htop replacement with nice graphs

    # --- File managers --------------------------------------------------------
    lf                    # terminal file manager (keyboard-driven)
    mc                    # midnight commander, two-panel classic

    # --- Compression / archiving ----------------------------------------------
    zip
    gzip
    gnutar

    # --- Remote / sync --------------------------------------------------------
    openssh
    rsync
    sshfs                 # mount remote filesystems over SSH
    maestral              # lightweight Dropbox client

    # --- Encryption -----------------------------------------------------------
    gocryptfs             # fuse-based encrypted overlay filesystem

    # --- Session / multiplexing -----------------------------------------------
    tmux                  # terminal multiplexer
    dtach                 # detach/reattach a process from its terminal

    # --- Build tools ----------------------------------------------------------
    cmake
    git
    git-lfs               # large file storage extension for git

    # --- Media / documents ----------------------------------------------------
    imagemagick           # image conversion and manipulation
    masterpdfeditor4      # PDF editor (unfree)

    # --- Libraries (needed by Python extensions and other builds) -------------
    readline
    libffi
    openssl

    # --- Python ---------------------------------------------------------------
    python312
    python312Packages.pip
    python312Packages.setuptools
    python312Packages.wheel
    # Tip: for project-specific Python deps, prefer `uv` or `nix develop`.

    # --- JavaScript -----------------------------------------------------------
    nodejs_24             # includes npm

    # --- AI / LLM tools -------------------------------------------------------
    aichat                # CLI chat client supporting multiple LLM backends
    ollama                # run LLMs locally (llama3, mistral, etc.)
    llama-cpp             # low-level inference engine; used by ollama and others

    # --- GUI apps -------------------------------------------------------------
    vscode                # Visual Studio Code (unfree)
    brave                 # privacy-focused browser (unfree)

  ];

  # ---------------------------------------------------------------------------
  # VSCode extensions
  # Managed declaratively so they survive a fresh vscode install.
  # ---------------------------------------------------------------------------
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      bbenoist.nix                       # Nix language support
      esbenp.prettier-vscode             # code formatter
      eamodio.gitlens                    # enhanced git blame / history
      ritwickdey.liveserver              # live-reload dev server
      ms-vscode-remote.remote-ssh        # SSH remote development
      yzhang.markdown-all-in-one         # markdown preview and shortcuts
    ];
  };

  # ---------------------------------------------------------------------------
  # Nix settings — enable flakes and new nix CLI in home-manager shells
  # ---------------------------------------------------------------------------
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };

  # ---------------------------------------------------------------------------
  # Environment variables — sourced into every login shell
  # ---------------------------------------------------------------------------
  home.sessionVariables = {
    EDITOR = "hx";
    GIT_EDITOR = "hx";
    # Preserve the custom PS1 inside `nix-shell` (which normally resets it).
    NIX_SHELL_PRESERVE_PROMPT = "1";
  };

  # ---------------------------------------------------------------------------
  # Bash — prompt and shell init
  # PS1 is set in initExtra (not sessionVariables) so that the subshell
  # expansion \$(git branch ...) and $SHLVL are evaluated at prompt time,
  # not at shell startup.
  # Prompt format: user@host #<nesting-level> <cwd> [<git-branch>]
  # ---------------------------------------------------------------------------
  programs.bash = {
    enable = true;
    initExtra = ''
      export PATH="$HOME/.local/bin:$PATH"
      PS1="\e[30;48;5;214m\u@\h #$SHLVL \w [\$(git branch -q --show-current 2>/dev/null)]\e[0m\n$ "
    '';
  };
}
EOF
sed -i "s/__USER__/$USER/g; s|__HOME__|$HOME|g" "$HOME_MANAGER_DIR/home.nix"

# ---------------------------------------------------------------------------
# 6. Clear the nix profile so home-manager can take over package management.
#    Packages installed imperatively (via nix-env or nix profile add) conflict
#    with home-manager trying to install the same packages declaratively.
# ---------------------------------------------------------------------------
echo ">>> Clearing nix profile so home-manager can manage all packages..."
nix --extra-experimental-features 'nix-command flakes' profile list 2>/dev/null \
  | grep "^Name:" \
  | sed 's/^Name:[[:space:]]*//' \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | xargs -r nix --extra-experimental-features 'nix-command flakes' profile remove \
  || true

# ---------------------------------------------------------------------------
# 7. Remove files that home-manager will manage.
#    Must happen before any `home-manager switch`, which refuses to clobber
#    existing files even on a first run.
# ---------------------------------------------------------------------------
echo ">>> Removing files that home-manager will manage (existing content is lost)..."
rm -f \
  "$HOME/.bash_profile" "$HOME/.bash_profile.backup" \
  "$HOME/.bashrc"       "$HOME/.bashrc.backup" \
  "$HOME/.profile"      "$HOME/.profile.backup" \
  "$HOME/.config/nix/nix.conf"

# ---------------------------------------------------------------------------
# 7. Install the home-manager binary (first run only), then apply config
#    Using `nix profile install` rather than `nix run ... --switch` to keep
#    installation and activation as separate steps.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 8. Apply the home-manager configuration.
#    First run: use `nix run` to avoid pre-installing home-manager into the
#    profile (home-manager installs itself via programs.home-manager.enable).
#    Subsequent runs: use the already-managed home-manager binary directly.
# ---------------------------------------------------------------------------
echo ">>> Applying home-manager configuration..."
if ! command -v home-manager &>/dev/null; then
  NIX_CONFIG="experimental-features = nix-command flakes" \
    nix run nixpkgs#home-manager -- switch --flake "$HOME_MANAGER_DIR#$USER"
else
  NIX_CONFIG="experimental-features = nix-command flakes" \
    home-manager switch --flake "$HOME_MANAGER_DIR#$USER"
fi

# ---------------------------------------------------------------------------
# 9. Install Claude Code via npm (Node.js is now available from home-manager)
#    Kept outside Nix because it self-updates independently.
#
#    npm install -g tries to write into the Nix store, which is read-only.
#    Fix: point npm's global prefix to ~/.local so everything stays in $HOME.
#
#    We also add ~/.local/bin to PATH now (home-manager does this for login
#    shells, but the current script may not have reloaded the profile yet).
# ---------------------------------------------------------------------------
NPM_PREFIX="$HOME/.local"
mkdir -p "$NPM_PREFIX/lib" "$NPM_PREFIX/bin"
export PATH="$NPM_PREFIX/bin:$PATH"

if [ ! -f "$NPM_PREFIX/bin/claude" ]; then
  echo ">>> Installing Claude Code (npm prefix: $NPM_PREFIX)..."
  npm install -g --prefix "$NPM_PREFIX" @anthropic-ai/claude-code
else
  echo ">>> Claude Code already installed, skipping."
fi

echo ""
echo "Done. Reloading shell..."
exec "$SHELL" -l
