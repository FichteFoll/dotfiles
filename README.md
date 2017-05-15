# FichteFoll's dotfiles

These are my dotfiles
as I use them on Arch Linux.
Feel free to use them however you like.

The files are managed with *stow*,
the GNU software package installation manager.
See [here][stow-guide] for an introduction.

[stow-guide]: http://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html

A convenience bash script 
to install all packages at once
is also included: `install-all`.
Packages are installed into `$HOME`.
All further arguments to it are forwarded directly to `stow`
(e.g. `-R` to "restow").
