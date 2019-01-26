""
" @section Introduction, intro
" @stylized TypeVim
" @library
" @order intro functions make
" A library providing a crude, JavaScript-esque class system in vimscript.
"
" vimscript allows users to assign Funcrefs into a dictionary; these functions,
" if declared with the |[dict]| attribute, will be able to access and modify
" their "owner" dictionary through a variable (`l:self`) accessible from
" within their function body. This allows for object-oriented programming
" (OOP).
"
" Unfortunately, vimscript does not provide for safe and convenient OOP. It
" lacks inbuilt type checking (like what the TypeScript compiler might
" provide), for instance. It also lacks explicit support for OOP features like
" polymorphism.
"
" TypeVim is meant to provide a sensible, standardized framework for "native"
" object-oriented programming in vimscript.

"""""""""""""""""""""""""""""""""""AUTOLOAD"""""""""""""""""""""""""""""""""""""

""
" When invoked from a namespaced autoload function, returns a string
" containing the namespace of the calling function, e.g. if invoked from
" `myplugin#ExampleObject#New()`, this function will
" return the string `'myplugin#ExampleObject#'`.
"
" If [funcname] is provided, it will be appended to the returned string.
"
" @default funcname=""
" @throws BadValue when the invoking function is not a namespaced function inside an `autoload/` directory, or if its name is malformed.
" @throws WrongType if [funcname] is not a string.
function! typevim#AutoloadPrefix(...) abort
  let a:funcname = maktaba#ensure#IsString(get(a:000, 0, ''))
  let l:callstack = expand('<sfile>')

  let l:invoker = matchstr(l:callstack,
      \ '\zs[^ .]*\ze\.\.typevim#AutoloadPrefix')

  let l:i = len(l:invoker) - 1 | while l:i ># -1
    let l:char = l:invoker[l:i]
    if l:char ==# '#' | break | endif
  let l:i -= 1 | endwhile
  if l:i ==# -1
    " if the funcname contains no #'s, then this isn't an autoload function
    throw maktaba#error#BadValue(
        \ "Invoking function doesn't appear(?) to be an autoload function: %s, "
        \ . 'from callstack: %s', l:invoker, l:callstack)
  elseif l:i ==# 0  " funcname like: '#Foo()' (no filename?)
    throw maktaba#error#Failure('Failed to parse function name: %s, '
        \ . 'from callstack: %s', l:invoker, l:callstack)
  endif

  return l:invoker[ : l:i].a:funcname
endfunction
