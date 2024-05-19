# my.sh

`my.sh` is the file I use to setup my Linux environment and customize my working shell. I use it on my home Linux machine as well as on my remote Linux VMs. After a clean OS installed (Ubuntu, Manjaro, CentOS, does not really matter) I simply put the following code in `~/bashrc`:

```
mysh() {
    exec bash -c "$(curl https://raw.githubusercontent.com/mdipierro/my.sh/master/my.sh)"
}
```

and, in bash, I type `mysh` to enter my environment. I do not install any program ever on the machine as everything I need is provided by Nix.

[](console.png)

The script does the following:

- If not installed, it installs Nix (not NixOS, just Nix).
- It creates a /temp/shell.nix file which contains the list of Nix of package that I want and defines some covenience functions (details below).
- It replace the bash shell with the Nix shell.

The first time you run it, it may take a few minutes. Occasionally it will update packages and therefore it can take a few seconds to enter the shell. Most time it is instantanous.

## What does it install?

- Nix
- Some tools like qemacs (a lighweight version of emacs), zip, mc, git, tmux, cmake, openssh.
- Python311 incluing pip, pylint, black, isort, etc.
- A modified version Google Chromium without Google customizations.
- VSCode and some useful plugins (ssh, syntax highlighting, etc.)

You can modify it to install what you need.

## What does it define?

- A custom bash prompt that shows username, hostname, current folder, nestiness level of current shell, git branch if in a git repo.
- A `venv` function which can be invoked in any folder. It creates (or updates) and enters a python venv but stores the venv in `~/.venvs/{path}`. This prevents polluting the current folder with the venv folder.
- An `overlay` function. When called, it created a layered file system on top of the current folder and enters in it. This allows me to work in the folder and simply type `exit` to discard any changes made inside the folder. This allows me to build stuff in the folder without polluting it.
- A `cleaup` function which deletes temporary files created by python or the editor.


## What if I need other packages?

As I said, I never install anything on the machine other this script. If I am in a folder that needs, for example, a Rust compiler, I simply type (notice no sudo):

```
nix-shell -p rustc
```

when I need it and it gets added to the existing Nix packages and my shell bumps of on. In folders that contain code with many dependencies I create their own `shell.nix` file.

## Example?

```
```

## Warning

This file is for personal use. I am only posting it publicly because I want to access it from everywhere. Also it may be useful to others as an example. I will change this file as my need changes. If you like the idea copy it and modify it but do not rely on this repo.

## License

3-clause BSD