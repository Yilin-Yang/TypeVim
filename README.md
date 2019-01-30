TypeVim [ALPHA]
================================================================================
TypeVim is a plugin built to make object-oriented programming in VimL easier. It
provides helper functions that allow users to more easily define their own
types, define polymorphic types, and preserve class invariants within instances
of those types.

It also includes some goodies, like a `bind` function; a pretty-printer for
lists,, dictionaries, and Partials (even when these objects are
self-referencing); and a *roughly* [A+ compliant](https://promisesaplus.com/)
implementation of Promises, all in pure VimL.

I wrote this plugin to cut down on boilerplate in my other plugins, not
necessarily because I expect others to use it (though they're certainly free to
do so, if they wish!). There do exist [other](https://github.com/vim-scripts/vimpp)
[plugins](https://github.com/rizzatti/funcoo.vim) to fill this niche, but those
I could find seem unmaintained and largely disused: the examples I've just
linked haven't been updated in around a decade, as of the time of writing.

**Be warned that TypeVim is still in alpha, and that I make no guarantees of API
stability at this time.**

License
--------------------------------------------------------------------------------
MIT
