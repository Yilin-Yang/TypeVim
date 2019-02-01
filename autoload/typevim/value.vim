let s:TYPE_ATTR = typevim#attribute#TYPE()
let s:RESERVED_ATTRIBUTES = typevim#attribute#ATTRIBUTES_AS_DICT()

""
" Returns 1 when the given {typename} is valid, 0 otherwise.
"
" A valid typename is a string of uppercase Latin letters, lowercase Latin
" letters, numbers, and underscores. It must start with a capital letter, and
" cannot contain "unusual" characters, e.g. accented Latin letters, emoji,
" etc.
"
" {typename} cannot be an empty string, nor can it be a "reserved attribute".
" See @section(reserved) for more details.
function! typevim#value#IsValidTypename(typename) abort
  if !maktaba#value#IsString(a:typename) || empty(a:typename)
      \ || has_key(s:RESERVED_ATTRIBUTES, a:typename)
    return 0
  endif
  return match(a:typename, '^[A-Z]\{1}[A-Za-z0-9_]*$') ==# 0
endfunction

""
" Returns 1 when the given {id} is a a valid identifier, 0 otherwise.
"
" A valid identifier must meet the same requirements as a valid typename (see
" @function(typevim#value#IsValidTypename)), but can start with either a
" lowercase or uppercase letter.
function! typevim#value#IsValidIdentifier(id) abort
  if !maktaba#value#IsString(a:id) || empty(a:id)
      \ || has_key(s:RESERVED_ATTRIBUTES, a:id)
    return 0
  endif
  return match(a:id, '^[A-Za-z]\{1}[A-Za-z0-9_]*$') ==# 0
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
  if maktaba#value#IsList(l:type_val)
    for l:type in l:type_val
      if !typevim#value#IsValidTypename(l:type)
        return 0
      endif
    endfor
    return 1
  else
    return 0
  endif
endfunction

""
" Returns 1 when the given {Obj} is an instance of the type {typename}, and 0
" otherwise.
"
" @throws BadValue if {typename} isn't a valid typename.
" @throws WrongType if {typename} isn't a string.
function! typevim#value#IsType(Obj, typename) abort
  if !maktaba#value#IsDict(a:Obj)
    return 0
  endif
  call maktaba#ensure#IsString(a:typename)
  call typevim#ensure#IsValidTypename(a:typename)
  if !has_key(a:Obj, s:TYPE_ATTR)
    throw s:NotTypeVimObject(a:Obj)
  endif

  let l:type_list = a:Obj[s:TYPE_ATTR]
  if !maktaba#value#IsList(l:type_list)
    throw s:NotTypeVimObject(a:Obj)
  endif
  for l:type in l:type_list
    if !typevim#value#IsValidTypename(l:type)
      throw maktaba#error#Failure(
          \ 'Object typelist contains invalid typename: %s, object is %s '
            \ . 'with typelist %s',
          \ typevim#object#ShallowPrint(l:type),
          \ typevim#object#ShallowPrint(a:Obj),
          \ typevim#object#ShallowPrint(l:type_list))
    endif
    if l:type ==# a:typename
      return 1
    endif
  endfor
  return 0
endfunction

function! s:NotTypeVimObject(Obj) abort
  throw maktaba#error#BadValue('Given object is not a TypeVim object: %s',
      \ typevim#object#ShallowPrint(a:Obj))
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
" If the Funcref {Func} is a Partial, decomposes {Func} into a four-element
" list containing: first, the function name; second, the Funcref itself;
" third, the bound arguments; and fourth, the bound dictionary. The latter two
" elements can be empty if {Func} is not bound to arguments or a dictionary,
" respectively.
"
" @throws WrongType if {Func} is not a Funcref.
function! typevim#value#DecomposePartial(Func) abort
  call maktaba#ensure#IsFuncref(a:Func)
  let l:funcname   = get(a:Func, 'name')
  let l:Funcref    = get(a:Func, 'func')
  let l:bound_args = get(a:Func, 'args')
  let l:bound_dict = get(a:Func, 'dict')
  return [l:funcname, l:Funcref, l:bound_args, l:bound_dict]
endfunction

""
" When invoked from a namespaced autoload function, return the name of the
" function {num_levels_down} the callstack, e.g. if called with
" {num_levels_down} = 2, get the callstack (as as string), strip this function
" from its top, then strip the function that called this function from its
" top, and then return the topmost function remaining
"
" If [funcname] is provided, it will be prefixed with `"#"` and appended to
" the returned string.
"
" Example inputs and outputs:
" >
"   function! Foo() abort
"     " current callstack: function MainFunc[2]..<SNR>215_ScriptFunc[1]..Foo
"
"     " echoes 'Foo', the name of the calling function
"     echo typevim#value#GetStackFrame(0)
"
"     " echoes '<SNR>215_ScriptFunc'
"     echo typevim#value#GetStackFrame(1)
"
"     " echoes 'MainFunc'
"     echo typevim#value#GetStackFrame(2)
"
"     " ERROR(NotFound)
"     echo typevim#value#GetStackFrame(3)
"   endfunction
" <
"
" @default funcname=""
" @throws NotFound if there is no stack frame {num_levels_down}.
" @throws WrongType if {num_levels_down} is not a number or [funcname] is not a string.
function! typevim#value#GetStackFrame(num_levels_down, ...) abort
  call maktaba#ensure#IsNumber(a:num_levels_down)
  let a:funcname = maktaba#ensure#IsString(get(a:000, 0, ''))

  " strip GetStackFrame from the callstack to get initial_callstack
  let l:strip_topmost_pat = '\zs.*\ze\.\.[^ .]\{-}$'
  let l:initial_callstack = matchstr(expand('<sfile>'), l:strip_topmost_pat)
  let l:callstack = l:initial_callstack

  let l:removed = 0 | while l:removed <# a:num_levels_down && !empty(l:callstack)
    let l:callstack = matchstr(l:callstack, l:strip_topmost_pat)
  let l:removed += 1 | endwhile

  if l:removed <# a:num_levels_down || empty(l:callstack)
    throw maktaba#error#NotFound(
        \ 'Popping to num_levels_down: %d would pop entire callstack: %s',
        \ a:num_levels_down,
        \ l:initial_callstack)
  endif

  let l:to_return = matchstr(l:callstack, '\zs[^ .]*\ze\[[0-9]*\]$')
  return l:to_return
endfunction
