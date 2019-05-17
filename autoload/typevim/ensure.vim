""
" Throws an ERROR(MissingFeature) if the current version of vim does not
" support |Partial|s.
"
" Returns 1.
function! typevim#ensure#HasPartials() abort
  if !s:HAS_PARTIALS
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not support Partials and/or the ability to '
        \ . 'get() the components of a Partial.')
  endif
  return 1
endfunction
let s:HAS_PARTIALS = typevim#value#HasPartials()

""
" Throws an ERROR(MissingFeature) if the current version of vim does not
" support |lambda|s.
"
" Returns 1.
function! typevim#ensure#HasLambdas() abort
  if !s:HAS_LAMBDAS
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not support lambdas.')
  endif
  return 1
endfunction
let s:HAS_LAMBDAS = typevim#value#HasLambdas()

""
" Throws an ERROR(MissingFeature) if the current version of vim does not
" have |v:t_TYPE| constants.
"
" Returns 1.
function! typevim#ensure#HasTypeConstants() abort
  if !s:HAS_TYPECONSTANTS
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not have type constants, '
        \ . 'e.g. v:t_bool, v:t_dict, etc.')
  endif
  return 1
endfunction
let s:HAS_TYPECONSTANTS = typevim#value#HasTypeConstants()

""
" Throws an ERROR(MissingFeature) if the current version of vim does not
" support |setbufline()|.
"
" Returns 1.
function! typevim#ensure#HasSetBufline() abort
  if !s:HAS_SETBUFLINE
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not support setbufline().')
  endif
  return 1
endfunction
let s:HAS_SETBUFLINE = typevim#value#HasSetBufline()

""
" Throws an ERROR(MissingFeature) if the current version of vim will
" incorrectly terminate a timer if an exception occurs inside of a try-catch
" statement in the timer's callback function.
"
" Returns 1.
function! typevim#ensure#HasTimerTryCatchPatch() abort
  if !s:HAS_TIMERTRYCATCHPATCH
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not have patched timer exception handling.')
  endif
  return 1
endfunction
let s:HAS_TIMERTRYCATCHPATCH = typevim#value#HasTimerTryCatchPatch()

""
" Throws an ERROR(MissingFeature) if the current version of vim does not
" support |appendbufline()|.
"
" Returns 1.
function! typevim#ensure#HasAppendBufline() abort
  if !s:HAS_APPENDBUFLINE
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not support appendbufline().')
  endif
  return 1
endfunction
let s:HAS_APPENDBUFLINE = typevim#value#HasAppendBufline()

""
" Throws an ERROR(MissingFeature) if the current version of vim does not
" support |deletebufline()|.
"
" Returns 1.
function! typevim#ensure#HasDeleteBufline() abort
  if !s:HAS_DELETEBUFLINE
    throw maktaba#error#MissingFeature(
        \ 'This vim version does not support deletebufline().')
  endif
  return 1
endfunction
let s:HAS_DELETEBUFLINE = typevim#value#HasDeleteBufline()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Returns {Val} if it's positive. Else, throws ERROR(BadValue).
" Throws ERROR(WrongType) if {Val} is not a number.
function! typevim#ensure#IsPositive(Val) abort
  if maktaba#ensure#IsNumber(a:Val) ># 0
    return a:Val
  endif
  throw maktaba#error#BadValue('Given value not a positive integer: %d', a:Val)
endfunction

""
" Returns {Val} if it's negative. Else, throws ERROR(BadValue).
" Throws ERROR(WrongType) if {Val} is not a number.
function! typevim#ensure#IsNegative(Val) abort
  if maktaba#ensure#IsNumber(a:Val) <# 0
    return a:Val
  endif
  throw maktaba#error#BadValue('Given value not a negative integer: %d', a:Val)
endfunction

""
" Returns {Val} if it's non-negative. Else, throws ERROR(BadValue).
" Throws ERROR(WrongType) if {Val} is not a number.
function! typevim#ensure#IsNonNegative(Val) abort
  if maktaba#ensure#IsNumber(a:Val) >=# 0
    return a:Val
  endif
  throw maktaba#error#BadValue(
      \ 'Given value not a non-negative integer: %d', a:Val)
endfunction

""
" Returns {Val} if it's not positive. Else, throws ERROR(BadValue).
" Throws ERROR(WrongType) if {Val} is not a number.
function! typevim#ensure#IsNonPositive(Val) abort
  if maktaba#ensure#IsNumber(a:Val) <=# 0
    return a:Val
  endif
  throw maktaba#error#BadValue(
      \ 'Given value not a non-positive integer: %d', a:Val)
endfunction

""
" Returns {Val} if it's greater than {Ref}. Else, throws ERROR(BadValue).
" Throws ERROR(WrongType) if {Val} or {Ref} are not numbers.
function! typevim#ensure#IsGreaterThan(Val, Ref) abort
  call maktaba#ensure#IsNumber(a:Val)
  call maktaba#ensure#IsNumber(a:Ref)
  if maktaba#ensure#IsNumber(a:Val) ># a:Ref
    return a:Val
  endif
  throw maktaba#error#BadValue(
      \ 'Given value %d not greater than %d', a:Val, a:Ref)
endfunction

""
" Returns {Val} if it's less than {Ref}. Else, throws ERROR(BadValue).
" Throws ERROR(WrongType) if {Val} or {Ref} are not numbers.
function! typevim#ensure#IsLessThan(Val, Ref) abort
  call maktaba#ensure#IsNumber(a:Val)
  call maktaba#ensure#IsNumber(a:Ref)
  if maktaba#ensure#IsNumber(a:Val) <# a:Ref
    return a:Val
  endif
  throw maktaba#error#BadValue(
      \ 'Given value %d not less than %d', a:Val, a:Ref)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Throws an ERROR(WrongType) if the given {Val} is not 1, 0, |v:true|, or
" |v:false|. Returns the given {Val} for convenience.
function! typevim#ensure#IsBool(Val) abort
  if !typevim#value#IsBool(a:Val)
    throw maktaba#error#WrongType(
        \ 'Expected a boolean. Got a %s.',
        \ maktaba#value#TypeName(a:Val))
  endif
  return a:Val
endfunction

""
" Throws an ERROR(BadValue) if the given {typename} is not a valid typename,
" along with the reason it's not a valid typename; otherwise, does nothing.
"
" Returns the given {typename} for convenience.
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
  return a:typename
endfunction

""
" Throws an ERROR(BadValue) if the given {id} is not a valid identifier,
" along with the reason it's not a valid identifier; otherwise, does nothing.
"
" Returns the given {id} for convenience.
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
    if match(a:id[0], '[A-Za-z]') ==# -1
      throw maktaba#error#BadValue('Identifier must start with letter: '.a:id)
    endif
    let l:idx = 1 | while l:idx <# len(a:id)
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
  return a:id
endfunction

""
" Throws an ERROR(BadValue) if the given {id} is not a valid interface
" property with a reason; otherwise, does nothing.
"
" Returns the given {id} for convenience.
"
" @throws WrongType if the given {id} is not a string.
function! typevim#ensure#IsValidInterfaceProp(id) abort
  if !maktaba#value#IsString(a:id)
    throw maktaba#error#WrongType('Given "id" is not a string: %s',
        \ typevim#object#ShallowPrint(a:id))
  endif
  if !typevim#value#IsValidInterfaceProp(a:id)
    if empty(a:id)
      throw maktaba#error#BadValue(
          \ 'Expected a non-empty string for an interface property.')
    endif
    if match(a:id[0], '[A-Za-z_$]') ==# -1
      throw maktaba#error#BadValue(
          \ 'Interface property must start with letter, _, or $: '.a:id)
    endif
    let l:idx = 1 | while l:idx <# len(a:id)
      let l:char = a:id[l:idx]
      if match(l:char, '[A-Za-z0-9_$]') ==# -1
          \ && !(l:idx ==# len(a:id) - 1 && l:char ==# '?')
      throw maktaba#error#BadValue(
          \ 'Given interface property has illegal character ''%s'' at index: %d',
          \ l:char, l:idx)
      endif
    let l:idx += 1 | endwhile
    throw maktaba#error#Failure(
        \ 'Reported that interface property "%s" was invalid, but it seems to '
        \ . 'be okay?',
        \ a:id)
  endif
  return a:id
endfunction

""
" Throws an ERROR(WrongType) if the given {Val} is not equal to a |v:t_TYPE|
" constant.
"
" Returns {Val} for convenience.
function! typevim#ensure#IsTypeConstant(Val) abort
  if !typevim#value#IsTypeConstant(a:Val)
    throw maktaba#error#WrongType('Given item is not a v:t_TYPE constant: %s',
        \ typevim#object#ShallowPrint(a:Val))
  endif
  return a:Val
endfunction

""
" Throws an ERROR(WrongType) if the given {Val} is not a valid TypeVim object.
"
" Returns {Val} for convenience.
function! typevim#ensure#IsValidObject(Val) abort
  if !typevim#value#IsValidObject(a:Val)
    throw maktaba#error#WrongType('Given item is not a TypeVim object: %s',
        \ typevim#object#ShallowPrint(a:Val))
  endif
  return a:Val
endfunction

""
" Throws an ERROR(WrongType) if the given {Obj} is not an instance of the type
" {typename}.
"
" Returns {Obj} for convenience.
"
" @throws BadValue if {Obj} is not a dict or {typename} is not a string.
function! typevim#ensure#IsType(Obj, typename) abort
  if !(typevim#value#IsDict(a:Obj) && maktaba#value#IsString(a:typename))
    throw maktaba#error#BadValue(
        \ 'Gave bad arguments to IsType (should be dict and string): [%s, %s]',
        \ typevim#object#ShallowPrint(a:Obj),
        \ typevim#object#ShallowPrint(a:typename))
  endif
  if !typevim#value#IsType(a:Obj, a:typename)
    throw maktaba#error#WrongType('Given object %s is not of type: %s',
        \ typevim#object#ShallowPrint(a:Obj, 2), a:typename)
  endif
  return a:Obj
endfunction

""
" Throws an ERROR(WrongType) if the given {Obj} is not a |dict|.
"
" Returns {Obj} for convenience.
"
" See @function(typevim#value#IsDict) for further details.
function! typevim#ensure#IsDict(Obj) abort
  if type(a:Obj) !=# s:DICT_TYPE
    throw maktaba#error#WrongType('Expected a Dictionary. Got a %s.',
        \ maktaba#value#TypeName(a:Obj))
  endif
  return a:Obj
endfunction
let s:DICT_TYPE = typevim#Dict()

""
" Throws an ERROR(WrongType) if the given {Obj} is not a |list|.
"
" Returns {Obj} for convenience.
"
" See @function(typevim#value#IsList) for further details.
function! typevim#ensure#IsList(Obj) abort
  if type(a:Obj) !=# s:LIST_TYPE
    throw maktaba#error#WrongType('Expected a List. Got a %s.',
        \ maktaba#value#TypeName(a:Obj))
  endif
  return a:Obj
endfunction
let s:LIST_TYPE = typevim#List()

""
" Throws an ERROR(WrongType) if the given {Obj} is not an implementation of
" {Interface}.
"
" Returns {Obj} for convenience.
"
" @throws BadValue if {Obj} is not a dict or {Interface} is not a TypeVim interface.
function! typevim#ensure#Implements(Obj, Interface) abort
  try
    let l:is_implementation = typevim#value#Implements(a:Obj, a:Interface)
  catch /ERROR(WrongType)/
    throw maktaba#error#BadValue(
        \ 'Gave bad arguments to Implements (should be a dictionary and a '
          \ . 'TypeVim interface): [%s, %s]',
        \ typevim#object#ShallowPrint(a:Obj),
        \ typevim#object#ShallowPrint(a:Interface))
  endtry
  if l:is_implementation | return a:Obj | endif
  throw maktaba#error#WrongType(
      \ 'Object does not implement interface: %s',
      \ a:Interface[typevim#attribute#INTERFACE()])
endfunction
