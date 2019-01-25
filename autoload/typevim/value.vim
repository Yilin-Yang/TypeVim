let s:TYPE_ATTR = typevim#attribute#TYPE()

""
" Returns 1 when the given {typename} is valid, 0 otherwise.
"
" A valid typename is a string of uppercase Latin letters, lowercase Latin
" letters, numbers, and underscores. It must start with a capital letter, and
" cannot contain "unusual" characters, e.g. accented Latin letters, emoji,
" etc.
"
" {typename} cannot be an empty string.
function! typevim#value#IsValidTypename(typename) abort
  if !maktaba#value#IsString(a:typename) || empty(a:typename)
    return 0
  endif
  return match(a:typename, '^[A-Z]\{1}[A-Za-z0-9_]*$') ==# 0
endfunction

""
" Returns 1 when the given {id} is a a valid identifier, 0 otherwise.
"
" A valid identifier must meet the same requirements as a valid typename (see
" @function(typevim#value#IsValidTypename)), but does not need to start with a
" capital letter.
function! typevim#value#IsValidIdentifier(id) abort
  if !maktaba#value#IsString(a:id) || empty(a:id)
    return 0
  endif
  return match(a:id, '^[A-Za-z0-9_]*$') ==# 0
endfunction

""
" Returns 1 when the given object is a valid TypeVim object, 0 otherwise.
"
" A valid TypeVim object is a dictionary; it contains a `'TYPE'` entry, also a
" dictionary, whose keys are typenames (see @function(IsValidTypename)) and
" whose values can be anything, though it is suggested that they be an
" arbitrary number (typically `1`).
function! typevim#value#IsValidObject(Val) abort
  if !(maktaba#value#IsDict(a:Val) && has_key(a:Val, s:TYPE_ATTR))
    return 0
  endif
  let l:type_val = a:Val[s:TYPE_ATTR]
  if maktaba#value#IsDict(l:type_val)
    for l:key in keys(l:type_val)
      if !typevim#value#IsValidTypename(l:key)
        return 0
      endif
    endfor
    return 1
  else
    return 0
  endif
endfunction

""
" Returns 1 when the given object is a Partial (see `:help Partial`) and 0
" otherwise.
function! typevim#value#IsPartial(Obj) abort
  if !maktaba#value#IsFuncref(a:Obj) | return 0 | endif
  if !empty(get(a:Obj, 'args')) || !empty(get(a:Obj, 'dict'))
    return 1
  endif
  return 0
endfunction

""
" If the Funcref {Func} is a Partial, decomposes {Func} into a two-element
" list containing: first, the bound arguments; and second, the bound
" dictionary. Both elements can be empty if {Func} is not bound to arguments
" or a dictionary, respectively.
"
" If {Func} is a Funcref, but not a Partial, returns an empty list. This is so
" that the return value of this function can be easily checked with `empty()`.
" @throws WrongType
function! typevim#value#DecomposePartial(Func) abort
  call maktaba#ensure#IsFuncref(a:Func)
  let l:bound_args = get(a:Func, 'args')
  let l:bound_dict = get(a:Func, 'dict')
  if empty(l:bound_args) && empty(l:bound_dict)
    return []
  endif
  return [l:bound_args, l:bound_dict]
endfunction
