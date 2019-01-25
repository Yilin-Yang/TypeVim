""
" Throws an ERROR(BadValue) if the given {typename} is not a valid typename,
" along with the reason it's not a valid typename; otherwise, does nothing.
"
" @throws WrongType if the given {typename} is not a string.
function! typevim#ensure#IsValidTypename(typename) abort
  if !maktaba#value#IsString(a:typename)
    throw maktaba#error#WrongType('Given "typename" is not a string: %s',
        \ typevim#object#ShallowPrint(a:typename))
  endif
  if !typevim#value#IsValidTypename(a:typename)
    if empty(a:typename)
      throw maktaba#error#BadValue('Expected a non-empty string for typename.')
    endif
    if match(a:typename[0], '[A-Z]') ==# -1
      throw maktaba#error#BadValue(
          \ 'typename must start with a capital letter: '.a:typename)
    endif
    let l:idx = 1 | while l:idx <# len(a:typename)
      let l:char = a:typename[l:idx]
      if match(l:char, '[A-Za-z0-9_]') ==# -1
      throw maktaba#error#BadValue(
          \ 'Given typename has illegal character ''%s'' at index: %d',
          \ l:char, l:idx)
      endif
    let l:idx += 1 | endwhile
    throw maktaba#error#Failure(
        \ 'Reported that typename "%s" was invalid, but it seems to be okay?',
        \ a:typename)
  endif
endfunction

""
" Throws an ERROR(BadValue) if the given {id} is not a valid identifier,
" along with the reason it's not a valid identifier; otherwise, does nothing.
"
" @throws WrongType if the given {id} is not a string.
function! typevim#ensure#IsValidIdentifier(id) abort
  if !maktaba#value#IsString(a:id)
    throw maktaba#error#WrongType('Given "id" is not a string: %s',
        \ typevim#object#ShallowPrint(a:id))
  endif
  if !typevim#value#IsValidIdentifier(a:id)
    if empty(a:id)
      throw maktaba#error#BadValue(
          \ 'Expected a non-empty string for an identifier.')
    endif
    let l:idx = 0 | while l:idx <# len(a:id)
      let l:char = a:id[l:idx]
      if match(l:char, '[A-Za-z0-9_]') ==# -1
      throw maktaba#error#BadValue(
          \ 'Given identifier has illegal character ''%s'' at index: %d',
          \ l:char, l:idx)
      endif
    let l:idx += 1 | endwhile
    throw maktaba#error#Failure(
        \ 'Reported that identifier "%s" was invalid, but it seems to be okay?',
        \ a:id)
  endif
endfunction
