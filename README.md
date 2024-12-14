# Setting Up Dotfiles Management

## Initial Setup

First, define a new alias that allows managing dotfiles from anywhere in the directory tree. The command name and the Git directory can be named however you like.

```bash
mkdir .dotfiles
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

To make this alias permanent, add it to your `.bashrc`, `.zshrc`, or the appropriate configuration file for your preferred shell.

```bash
# !! expands to the previous command
echo "alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'" >> ~/.bashrc
```

Next, initialize the repository and configure it to hide untracked files to make the status output cleaner.

```bash
dotfiles init
dotfiles config --local status.showUntrackedFiles no
```

Since this demo uses GitHub for sharing the repository, set the branch name to `main`:

```bash
dotfiles branch -M main
```

### Adding Configuration Files
Add any configuration files you want to store in your dotfiles repository. For this demo, we will start with `.bashrc`:

```bash
dotfiles add ~/.bashrc
dotfiles commit -m 'Initial commit with .bashrc'
```

### Pushing to a Remote Repository
To share this across machines, add a remote and push the repository. You don’t have to use GitHub specifically; any Linux machine or network share will work.

```bash
dotfiles remote add origin git@github.com:HappyCerberus/dotfiles-demo.git
dotfiles push -u origin main
```

## Setting Up on a Second Machine

On the second machine, define the alias, clone the repository, and check out the files:

```bash
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
git clone --bare git@github.com:HappyCerberus/dotfiles-demo.git $HOME/.dotfiles
dotfiles config --local status.showUntrackedFiles no
dotfiles checkout
```

### Resolving Conflicts
If you already have some of the dotfiles present, you might see this error:

```bash
error: The following untracked working tree files would be overwritten by checkout:
 .bashrc
Please move or remove them before you switch branches.
Aborting
```

To resolve this, back up or remove the conflicting files and try the checkout again:

```bash
mv ~/.bashrc ~/.bashrc_backup
dotfiles checkout
```

