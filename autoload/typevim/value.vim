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
" Returns 1 if this version of vim will, correctly, not terminate a timer
" if an exception occurs inside of a try-catch statement in the timer's
" callback function.
"
" If this is unsupported, @dict(Promise) resolution and rejection are not
" guaranteed to work correctly.
function! typevim#value#HasTimerTryCatchPatch() abort
  return has('patch-8.0.1067')
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
" Returns 1 when the given {Typename} is valid, 0 otherwise.
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
  if has_key(s:typenames_to_validity, a:Typename)
    return s:typenames_to_validity[a:Typename]
  endif
  let l:to_return = match(a:Typename, '^[A-Z]\{1}[A-Za-z0-9_]*$') ==# 0
  let s:typenames_to_validity[a:Typename] = l:to_return
  return l:to_return
endfunction
let s:typenames_to_validity = {}

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
" Valid interface properties must start with a letter (uppercase or
" lowercase), underscore, or dollar sign; the remaining characters may be
" letters (uppercase or lowercase), numbers, underscores, or dollar signs. The
" identifier may end with a question mark, to signifiy that the property is
" optional, though this question mark won't exist in "actual" interface
" implementations.
function! typevim#value#IsValidInterfaceProp(Id) abort
  if !maktaba#value#IsString(a:Id) || empty(a:Id)
      \ || has_key(s:RESERVED_ATTRIBUTES, a:Id)
    return 0
  endif
  return match(a:Id, '^[A-Za-z_$]\{1}[A-Za-z0-9_$]*[?]\{0,1}$') ==# 0
endfunction

""
" Returns 1 when the given {Val} is a number equal to a valid |v:t_TYPE|
" constant or @function(typevim#Any), and 0 otherwise.
function! typevim#value#IsTypeConstant(Val) abort
  return maktaba#value#IsNumber(a:Val) && a:Val >=# 0 && a:Val <=# 7
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
  if !typevim#value#IsDict(a:Val)
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
  if typevim#value#IsList(l:type_val)
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
  if !typevim#value#IsDict(a:Obj)
    return 0
  endif
  call maktaba#ensure#IsString(a:typename)
  call typevim#ensure#IsValidTypename(a:typename)
  if !has_key(a:Obj, s:TYPE_ATTR)  " no type attribute
    return 0
  endif

  let l:type_list = a:Obj[s:TYPE_ATTR]
  if !typevim#value#IsList(l:type_list)  " type attribute is malformed
    return 0
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
" Returns 1 when the given {Obj} is a |dict|, and 0 otherwise.
"
" Exactly like |maktaba#ensure#IsDict|, but optimized to be slightly faster.
" As of the time of writing, vim-maktaba's implementation constructs an empty
" dict with every call, while this function simply queries the |type()| of the
" {Obj} and compares that to @function(typevim#Dict).
function! typevim#value#IsDict(Obj) abort
  return type(a:Obj) ==# s:DICT_TYPE
endfunction
let s:DICT_TYPE = typevim#Dict()

""
" Returns 1 when the given {Obj} is a |list|, and 0 otherwise.
"
" Exactly like |maktaba#ensure#IsList|, but optimized to be slightly faster.
" See @function(typevim#value#IsDict) for further details.
function! typevim#value#IsList(Obj) abort
  return type(a:Obj) ==# s:LIST_TYPE
endfunction
let s:LIST_TYPE = typevim#List()

""
" Returns 1 when {Val} satisfies {constraint}, and 0 otherwise.
" @throws WrongType when {constraint} is not a dict.
function! s:SatisfiesConstraint(Val, constraint, property) abort
  call typevim#ensure#IsDict(a:constraint)
  let l:type = a:constraint.type
  let l:is_list = typevim#value#IsList(l:type)

  if a:constraint.is_tag
    if !l:is_list
      throw maktaba#error#Failure(
          \ 'Interface property "%s" is a tag, but the tag list is not a '
            \ . 'list of strings: %s',
          \ a:property,
          \ typevim#object#ShallowPrint(l:type))
    endif
    if !maktaba#value#IsString(a:Val) | return 0 | endif
    return index(l:type, a:Val) !=# -1
  elseif l:is_list
    if index(l:type, typevim#Any()) !=# -1
      return 1  " if the type list allows 'any', for some reason, return 1
    endif
    if typevim#value#IsDict(a:Val)
      if index(l:type, typevim#Dict()) !=# -1 | return 1 | endif
      " it's a dict, but 'dict' isn't a specified type
      " check if it implements an interface
      let l:i = 0 | while l:i <# len(l:type)
        let l:allowed_type = l:type[l:i]
        if !typevim#value#IsType(l:allowed_type, 'TypeVimInterface')
          let l:i += 1
          continue
        endif
        if typevim#value#Implements(a:Val, l:allowed_type)
          return 1
        endif
      let l:i += 1 | endwhile
      return 0  " does not implement an interface, nor is dict an allowed type
    else
      if index(l:type, type(a:Val)) ==# -1
        " edge case: check if it's a bool
        if typevim#value#IsBool(a:Val)
          return index(l:type, typevim#Bool()) !=# -1  " was bool allowed?
        endif
        return 0  " type of Val not found in list
      endif
      return 1
    endif
  else " it's a singular object
    if typevim#value#IsType(l:type, 'TypeVimInterface')
      return typevim#value#Implements(a:Val, l:type)
    elseif l:type ==# typevim#Any()
      return 1
    elseif l:type ==# typevim#Bool()
      return typevim#value#IsBool(a:Val)
    endif
    return type(a:Val) ==# l:type
  endif
endfunction

""
" Returns 1 when {Obj} is an implementation of {Interface}, and 0 otherwise.
"
" @throws WrongType if {Interface} is not a TypeVim interface (i.e. an object constructed through a call to @function(typevim#make#Interface).)
function! typevim#value#Implements(Obj, Interface) abort
  if !typevim#value#IsDict(a:Obj)
    return 0
  endif
  call typevim#ensure#IsType(a:Interface, 'TypeVimInterface')
  for [l:property, l:Constraints] in items(a:Interface)
    " don't consider TypeVim reserved attributes
    if has_key(s:RESERVED_ATTRIBUTES, l:property) | continue | endif

    " if it's non-optional and the object doesn't have it, reject;
    " or, if it's optional and the object doesn't have it, skip this property
    if !l:Constraints.is_optional && !has_key(a:Obj, l:property)
      return 0
    elseif l:Constraints.is_optional && !has_key(a:Obj, l:property)
      continue
    endif

    let l:Val = a:Obj[l:property]
    if !s:SatisfiesConstraint(l:Val, l:Constraints, l:property)
      return 0
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
" Comparison function that only compares the zero-indexed element of two
" two-element lists, {lhs} and {rhs}. Can be used to sort the two-element
" lists returned by a call to |items()| based exclusively on keys, without
" considering the values associated with those keys. This is useful when
" getting "|E724|: Unable to dump object with self-referencing container"
" errors on calls like `sort(items(some_dict))`.
"
" @throws BadValue if {lhs} or {rhs} don't have length 2.
" @throws WrongType if {lhs} or {rhs} are not lists.
function! typevim#value#CompareKeys(lhs, rhs)
  call typevim#ensure#IsList(a:lhs)
  call typevim#ensure#IsList(a:rhs)
  if len(a:lhs) !=# 2 || len(a:rhs) !=# 2
    throw maktaba#error#BadValue(
        \ 'typevim#value#CompareKeys only sorts "pairs" (2-elem lists), '
            \ . 'gave: %s, %s',
        \ typevim#object#ShallowPrint(a:lhs),
        \ typevim#object#ShallowPrint(a:rhs))
  endif
  let l:lkey = string(a:lhs[0])
  let l:rkey = string(a:rhs[0])
  if l:lkey ># l:rkey
    return 1
  elseif l:lkey ==# l:rkey
    return 0
  else  " l:lkey <# l:rkey
    return -1
  endif
endfunction

""
" When invoked from a namespaced autoload function, return the name of the
" function {num_levels_down} the callstack, e.g. if called with
" {num_levels_down} = 2, get the callstack (as as string), strip this function
" from its top, then strip the function that called this function from its
" top, and then return the topmost function remaining
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
" @throws NotFound if there is no stack frame {num_levels_down}.
" @throws WrongType if {num_levels_down} is not a number.
function! typevim#value#GetStackFrame(num_levels_down) abort
  call maktaba#ensure#IsNumber(a:num_levels_down)

  " strip GetStackFrame from the callstack to get initial_callstack
  let l:initial_callstack = matchstr(expand('<sfile>'), s:strip_topmost_pat)

  " check memo for precalculated value
  let l:memo_key = l:initial_callstack.'+++'.a:num_levels_down
  if has_key(s:callstacks_and_numlevels, l:memo_key)
    return s:callstacks_and_numlevels[l:memo_key]
  endif

  let l:callstack = l:initial_callstack
  let l:removed = 0 | while l:removed <# a:num_levels_down && !empty(l:callstack)
    let l:callstack = matchstr(l:callstack, s:strip_topmost_pat)
  let l:removed += 1 | endwhile

  if l:removed <# a:num_levels_down || empty(l:callstack)
    throw maktaba#error#NotFound(
        \ 'Popping to num_levels_down: %d would pop entire callstack: %s',
        \ a:num_levels_down,
        \ l:initial_callstack)
  endif

  let l:to_return = matchstr(l:callstack, '\zs[^ .]*\ze\[[0-9]*\]$')
  let s:callstacks_and_numlevels[l:memo_key] = l:to_return
  return l:to_return
endfunction
" memoized values for previous calls to GetStackFrame
" keys are strings formed by the following concatenation:
"     l:initial_callstack.'+++'.a:num_levels_down
" values are the final value l:to_return
let s:callstacks_and_numlevels = {}

""
" @private
function! typevim#value#StackHeightImpl(callstack) abort
  if empty(a:callstack) | return 0 | endif
  let l:num_frames = 1
  let l:i = 0 | while l:i <# len(a:callstack) - 1
    if a:callstack[l:i] ==# '.' && a:callstack[l:i + 1] ==# '.'
      let l:num_frames += 1
      let l:i += 1
    endif
  let l:i += 1 | endwhile
  return l:num_frames
endfunction

""
" Returns the height of the callstack, not including the stack frame allocated
" for this function.
function! typevim#value#StackHeight() abort
  let l:callstack = matchstr(expand('<sfile>'), s:strip_topmost_pat)
  return typevim#value#StackHeightImpl(l:callstack)
endfunction

" regex used for stripping the topmost stack frame
let s:strip_topmost_pat = '\zs.*\ze\.\.[^ .]\{-}$'
