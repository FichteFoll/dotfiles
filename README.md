# FichteFoll's dotfiles

These are my dotfiles
as I use them on Arch Linux.
Feel free to use them however you like.

The files are primaritly managed with *stow*,
the GNU software package installation manager.
See [here][stow-guide] for an introduction.

[stow-guide]: http://brandon.invergo.net/news/2012-05-26-using-gnu-stow-to-manage-your-dotfiles.html

A custom installation script,
which is a wrapper around *stow*
and does additional special operations,
is included: `install`.
Currently, this is mostly needed because of Sublime Text.
Packages are installed into `$HOME`.
See the source code for details.

**Note**: Considered WIP but works.
