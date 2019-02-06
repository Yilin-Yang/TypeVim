let s:TYPE_ATTR = typevim#attribute#TYPE()
let s:RESERVED_ATTRIBUTES = typevim#attribute#ATTRIBUTES_AS_DICT()
let s:CLEAN_UPPER = typevim#attribute#CLEAN_UPPER()

""
" Returns 1 if this version of vim supports |Partial| function references AND
" the ability to |get()| the components of a |Partial| or |Funcref| object,
" and 0 otherwise.
function! typevim#value#HasPartials() abort
  return has('patch-7.4.1842')
  " return has('patch-7.4.1836')
endfunction

""
" Returns 1 if this version of vim supports |lambda|s, and 0 otherwise.
function! typevim#value#HasLambdas() abort
  return has('patch-7.4.2044')
endfunction

""
" Returns 1 if this version of vim supports |v:t_TYPE| constants, and 0
" otherwise.
function! typevim#value#HasTypeConstants() abort
  return has('patch-7.4.2071')
endfunction

""
" Returns 1 if this version of vim supports |setbufline|, and 0 otherwise.
function! typevim#value#HasSetBufline() abort
  return has('patch-8.0.1039')
endfunction

""
" Returns 1 if this version of vim supports |appendbufline|, and 0 otherwise.
function! typevim#value#HasAppendBufline() abort
  return has('patch-8.1.0037')
endfunction

""
" Returns 1 if this version of vim supports |deletebufline|, and 0 otherwise.
function! typevim#value#HasDeleteBufline() abort
  return has('patch-8.1.0039')
endfunction

""
" Returns 1 if the given {Val} is 1, 0, |v:true|, or |v:false|. Does not
" compare against |v:true| or |v:false| if those constants are not defined in
" the running version of vim.
"
" This function is provided for use in plugins that use the |v:true| and
" |v:false| constants, because @function(maktaba#value#IsBool) will actually
" fail when given |v:true| or |v:false| as inputs: it only accepts a
" |v:t_number| equal to 0 or 1.
function! typevim#value#IsBool(Val) abort
  if exists('v:true')
    return maktaba#value#IsIn(a:Val, [0, 1, v:true, v:false])
  else
    return maktaba#value#IsBool(a:Val)
  endif
endfunction

""
" Returns 1 when the given {typename} is valid, 0 otherwise.
"
" A valid typename is a string of uppercase Latin letters, lowercase Latin
" letters, numbers, and underscores. It must start with a capital letter, and
" cannot contain "unusual" characters, e.g. accented Latin letters, emoji,
" etc.
"
" {Typename} cannot be an empty string, nor can it be a "reserved attribute".
" See @section(reserved) for more details.
function! typevim#value#IsValidTypename(Typename) abort
  if !maktaba#value#IsString(a:Typename) || empty(a:Typename)
      \ || has_key(s:RESERVED_ATTRIBUTES, a:Typename)
    return 0
  endif
  return match(a:Typename, '^[A-Z]\{1}[A-Za-z0-9_]*$') ==# 0
endfunction

""
" Returns 1 when the given {Id} is a a valid identifier, 0 otherwise.
"
" A valid identifier must meet the same requirements as a valid typename (see
" @function(typevim#value#IsValidTypename)), but can start with either a
" lowercase or uppercase letter.
function! typevim#value#IsValidIdentifier(Id) abort
  if !maktaba#value#IsString(a:Id) || empty(a:Id)
      \ || has_key(s:RESERVED_ATTRIBUTES, a:Id)
    return 0
  endif
  return match(a:Id, '^[A-Za-z]\{1}[A-Za-z0-9_]*$') ==# 0
endfunction

""
" Returns 1 when the given {Id} is a a valid interface property, 0 otherwise.
"
" A valid interface property must meet the same requirements as a valid
" identifier (see @function(typevim#value#IsValidTypename)), but can end with
" a question mark.
function! typevim#value#IsValidInterfaceProp(Id) abort
  if !maktaba#value#IsString(a:Id) || empty(a:Id)
      \ || has_key(s:RESERVED_ATTRIBUTES, a:Id)
    return 0
  endif
  return match(a:Id, '^[A-Za-z]\{1}[A-Za-z0-9_]*[?]\{0,1}$') ==# 0
endfunction

""
" Returns 1 when the given {Val} is a number equal to a valid |v:t_TYPE|
" constant, and 0 otherwise.
function! typevim#value#IsTypeConstant(Val) abort
  return maktaba#value#IsNumber(a:Val) && a:Val >=# 0 && a:Val <=# 6
endfunction

""
" Returns 1 when the given object is a valid TypeVim object, 0 otherwise.
"
" A valid TypeVim object is a dictionary. It shall contain the following
" attributes:
" - A TYPE list: a list of strings containing the names of every class in
"   the object's class hierarchy, with the original base class as the first
"   element and the "most derived" class as the last.
" - A CLEAN-UPPER: a member function, taking no arguments, that handles
"   clean-up for the object. This function may do nothing: if, for instance,
"   @function(typevim#make#Class) is not given a clean-upper, the resulting
"   object will be given a "dummy" clean-upper.
"
" See @section(reserved) for more details.
function! typevim#value#IsValidObject(Val) abort
  if !maktaba#value#IsDict(a:Val)
    return 0
  endif
  if !(has_key(a:Val, s:CLEAN_UPPER)
      \ && maktaba#value#IsFuncref(a:Val[s:CLEAN_UPPER]))
    return 0
  endif
  if has_key(a:Val, s:TYPE_ATTR)
    let l:type_val = a:Val[s:TYPE_ATTR]
  else
    return 0
  endif
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

""
" Returns 1 when {Obj} is an implementation of {Interface}, and 0 otherwise.
"
" @throws WrongType if {Obj} is not a dictionary, or if {Interface} is not a TypeVim interface (i.e. an object constructed through a call to @function(typevim#make#Interface).)
function! typevim#value#Implements(Obj, Interface) abort
  call maktaba#ensure#IsDict(a:Obj)
  call typevim#ensure#IsType(a:Interface, 'TypeVimInterface')
  for [l:property, l:Constraints] in items(a:Interface)
    if has_key(s:RESERVED_ATTRIBUTES, l:property) | continue | endif
    if !l:Constraints['is_optional'] && !has_key(a:Obj, l:property)
      return 0
    endif

    let l:type = l:Constraints['type']
    let l:Val = a:Obj[l:property]
    if l:Constraints['is_tag']  " l:type is a list of allowable strings
      if !maktaba#value#IsString(l:Val) | return 0 | endif
      if !maktaba#value#IsList(l:type)
        throw maktaba#error#Failure(
            \ 'Interface property "%s" is a tag, but the tag list is not a '
              \ . 'list of strings: %s',
            \ l:property,
            \ typevim#object#ShallowPrint(l:type))
      endif
      if index(l:type, l:Val) ==# -1 | return 0 | endif
    elseif maktaba#value#IsList(l:type)  " l:type is a list of allowable types
      if index(l:type, type(l:Val)) ==# -1 | return 0 | endif
    elseif maktaba#value#IsNumber(l:type)  " l:type is a single allowable type
      if l:type !=# type(l:Val) | return 0 | endif
    else
      throw maktaba#error#Failure(
          \ 'Interface object contains non-parsable constraint for '
            \ . 'property "%s": %s',
          \ l:property, typevim#object#ShallowPrint(l:Constraints))
    endif
  endfor
  return 1
endfunction

function! s:NotTypeVimObject(Obj) abort
  throw maktaba#error#BadValue('Given object is not a TypeVim object: %s',
      \ typevim#object#ShallowPrint(a:Obj))
endfunction

""
" Returns 1 when the given object is a Partial (see `:help Partial`) and 0
" otherwise.
function! typevim#value#IsPartial(Obj) abort
  call typevim#ensure#HasPartials()
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
  call typevim#ensure#HasPartials()
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
