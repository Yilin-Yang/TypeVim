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
" Returns 1 when the given object is a valid TypeVim object, 0 otherwise.
"
" A valid TypeVim object is a dictionary; it contains a `'TYPE'` entry, also a
" dictionary, whose keys are typenames (see @function(IsValidTypename)) and
" whose values can be anything, though it is suggested that they be an
" arbitrary number (typically `1`).
function! typevim#value#IsValidObject(val) abort
  if !(maktaba#value#IsDict(a:val) && has_key(a:val, 'TYPE'))
    return 0
  endif
  let l:type_val = a:val['TYPE']
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
