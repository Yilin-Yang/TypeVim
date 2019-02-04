TypeVim [ALPHA]
================================================================================
TypeVim is a plugin built to make object-oriented programming in VimL easier. It
provides helper functions that allow users to more easily define their own
types, define polymorphic types, and preserve class invariants within instances
of those types.

It also includes some goodies, like a `bind` function; a pretty-printer for
lists,, dictionaries, and Partials (even when these objects are
self-referencing); an [object-oriented wrapper](autoload/typevim/Buffer.vim)
around vim buffers; and a *roughly* [A+ compliant](https://promisesaplus.com/)
implementation of [Promises](autoload/typevim/Promise.vim), all in pure VimL.

I wrote this plugin to cut down on boilerplate in my other plugins, not
necessarily because I expect others to use it (though they're certainly free to
do so, if they wish!). There do exist [other](https://github.com/vim-scripts/vimpp)
[plugins](https://github.com/rizzatti/funcoo.vim) to fill this niche, but those
I could find seem unmaintained and largely disused: the examples I've just
linked haven't been updated in around a decade, as of the time of writing.

**Be warned that TypeVim is still in alpha, and that I make no guarantees of API
stability at this time.**

Prerequisites
--------------------------------------------------------------------------------
TypeVim requires *at least* [Vim 7.4.1842](https://github.com/vim/vim/commit/03e19a04ac2ca55643663b97b6ab94043233dcbd),
or practically any recent version of neovim.

That said, it is strongly recommended that you use at least [Vim 8.1.0039](https://github.com/vim/vim/commit/d79a26219d7161e9211fd144f0e874aa5f6d251e),
which is the earliest version of Vim that supports `deletebufline()`. Without
this function, TypeVim's `Buffer` object will use a crude fallback
implementation when modifying lines in the wrapped buffer.

### Dependencies
TypeVim depends on [vim-maktaba.](https://github.com/google/vim-maktaba/)

Installation
--------------------------------------------------------------------------------
With [vim-plug](https://github.com/junegunn/vim-plug),

```vim
call plug#begin('~/.vim/bundle')
" ...
Plug 'Yilin-Yang/TypeVim'

  " dependencies
  Plug 'Google/vim-maktaba'

" ...
call plug#end()
```

TypeVim also includes an [`addon-info.json`](https://github.com/google/vim-maktaba/wiki/Creating-Vim-Plugins-with-Maktaba#plugin_metadata)
file, allowing for dependency resolution (i.e. automatic installation of
`vim-maktaba`) in [compatible plugin managers.](https://github.com/MarcWeber/vim-addon-manager)

Basic Usage
--------------------------------------------------------------------------------
If you have the time, read through all of `:help TypeVim`.

If you want to get up to speed quickly, then:

**If using TypeVim for class writing,** skim `:help TypeVim-summary` (for
a broad overview of TypeVim's class system) and `:help TypeVim-make` (for info
on writing classes). Actual use would look something like:

```vim
"===================================
" myplugin/autoload/myplugin/Foo.vim
let s:typename = 'Foo'
function! myplugin#Foo#New(number) abort
  call maktaba#ensure#IsNumber(a:number)
  let l:prototype = {
      \ '__number': a:number,
      \ 'Func': typevim#make#Member('MemberFunc'),
      \ }
  return typevim#make#Class(
      \ s:typename, l:prototype, typevim#make#Member('CleanUp'))
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! myplugin#Foo#CleanUp() dict abort
  call s:CheckType(l:self)
  " delete all instances of the word 'trash' from the current buffer
  %s/trash//ge
endfunction

function! myplugin#Foo#MemberFunc() dict abort
  call s:CheckType(l:self)
  echo l:self['__number']
endfunction

"=============================
" myplugin/plugin/myplugin.vim
let g:foo_instance = myplugin#Foo#New(3)
call g:foo_instance.Func()  " prints 3
```

**If using TypeVim for its object-oriented `Buffer` wrapper,** skim `:help
TypeVim.Buffer`. Actual use would look something like this:

```vim
" creating a new vim buffer 'NewlyMade.txt' and then wrapping it,
let buffer_obj = typevim#Buffer#New({'bufname': 'NewlyMade.txt'})

" OR, giving the object ownership of the buffer with |bufnr| 2 and renaming
" it 'Existing.txt',
let buffer_obj = typevim#Buffer#New({'bufname': 'Existing.txt', 'bufnr': 2})

call buffer_obj.InsertLines(0, ['foo', 'bar'])  " prepend
" buffer now contains:
"  foo
"  bar

call buffer_obj.InsertLines('$', ['goo', 'gar'])  " append
" buffer now contains:
"  foo
"  bar
"  goo
"  gar

call buffer_obj.ReplaceLines(1, -1, [])  " note negative indexing on {endline}
" buffer is now empty

call buffer_obj.Open()  " open buffer in current window
" OR,
call buffer_obj.Switch()  " switch to a window that has this buffer open

call buffer_obj.CleanUp()  " bwipeout the buffer object
```

Contribution
--------------------------------------------------------------------------------
### Development
Documentation is generated using [vimdoc.](https://github.com/google/vimdoc)

```bash
# from project root, after installing vimdoc,
vimdoc .
```

TypeVim uses [vader.vim](https://github.com/junegunn/vader.vim) as its testing
framework. To run tests,

```bash
# from project root, with `vader.vim` installed,
cd test
./run_tests.sh
```

Tests are either "regular" or "standalone." On a typical run, all regular tests
will run in a single vim instance; after that instance exits, each standalone
test will run sequentially, a new vim instance being started for each one. This
is to help prevent side effects from altering the outcome of other tests.

See `./run_tests --help` for additional usage details.

```bash
# an example of ./run_tests.sh use that may be more useful during development:
#   run all tests in "visible" interactive neovim instances, using the given
#   neovim executable
./run_tests.sh -v --neovim -e /usr/local/bin/nvim
```

### Issue Reports and Pull Requests
Issue reports are welcome and encouraged, despite the project's early
development status. These can be feature requests, defect reports, or even
spelling and grammar fixes, since I haven't proofread the docs as thoroughly as
I might like.

Pull requests are also welcome, though I'd encourage you to open an Issue first,
so that I can offer feedback. I might reject pull requests for arbitrary reasons
(e.g. if the given feature doesn't align with (undocumented) "project goals," or
is implemented in a way that I think is cumbersome), but I would hate to reject
a PR after somebody's put major effort into making it work.

License
--------------------------------------------------------------------------------
MIT
