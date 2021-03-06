""""""""""""""""""""""""""""""""OBJECT METHODS""""""""""""""""""""""""""""""""""

""
" @private
" "Default" "virtual" clean-upper, used when performing "clean-up" for a
" derived class with multiple declared constructors. Calls clean-uppers in
" reverse order, i.e.  from the most- to least-derived classes in the object's
" class hierarchy.
function! typevim#object#CleanUp() dict abort
  if has_key(l:self, '___CLEAN_UPPERS___')
    let l:CleanUppers = l:self['___CLEAN_UPPERS___']
  else
    throw maktaba#error#Failure(
        \ 'Object should have a list of its multiple destructors, but could '
        \ . 'find none! Object: %s', typevim#object#ShallowPrint(l:self))
  endif
  if !typevim#value#IsList(l:CleanUppers)
    throw maktaba#error#Failure(
        \ "Object's list of destructors somehow replaced with non-list object? "
        \ . 'Found: %s, Object: %s', typevim#object#ShallowPrint(l:CleanUppers),
        \ typevim#object#ShallowPrint(l:self))
  endif
  let l:i = len(l:CleanUppers) - 1
  while l:i ># -1
    let l:CleanUpper = l:CleanUppers[l:i]
    call l:CleanUpper()
    let l:i -= 1
  endwhile
endfunction

""
" Returns a Partial consisting of the given {Funcref} that is bound to this
" particular {obj} and to [arglist], i.e. return `function(a:Funcref,
" a:arglist, a:obj)`.
"
" If the member function is already bound to an arglist, then [arglist] will
" be appended to the function's current arglist.
"
" If the {Funcref} function is already bound to a dict, throws an
" ERROR(NotAuthorized) exception unless the dict and {obj} are the same
" object; however, if [force_rebind] is 1, the bound dict will be replaced
" with the given {obj}.
"
" This function is comparable to the `bind()` method on class member
" functions in JavaScript, and to the `std::bind()` function in the C++
" standard library. Its primary purpose is to extract a "self-contained"
" class member Funcref that "remembers" its original `l:self`, even when
" it is assigned into another object. (This is done frequently in asynchronous
" event-based programming when passing callback functions.)
"
" See `:help Partial` for an explanation of why it would be bad not to do
" this. (In short, when a "non-bound" Funcref is assigned into another object,
" then when that object calls it, every `l:self` variable in the Funcref's
" definition will point to the NEW object, and NOT to the Funcref's original
" `l:self`; that invocation will then modify that new object as if it were the
" original `l:self`, even if it's of a different class entirely.)
"
" Note that argument parameters affect the RETURNED Funcref, NOT the Funcref
" that is given as an argument.
" >
"   " does NOT change obj.Method
"   call typevim#object#Bind(obj.Method, diff_obj)
"
"   " DOES change obj.Method
"   let obj.Method = typevim#object#Bind(obj.Method, diff_obj)
" <
"
" @throws NotAuthorized if {Funcref} is already bound to a dict that is not {obj} and [force_rebind] is 0.
" @throws WrongType if {obj} is not a dict, or if {Funcref} is not a Funcref, or if [arglist] is not a list.
function! typevim#object#Bind(Funcref, obj, ...) abort
  call maktaba#ensure#IsFuncref(a:Funcref)
  call typevim#ensure#IsDict(a:obj)
  let l:arglist = typevim#ensure#IsList(get(a:000, 0, []))
  let l:force_rebind = maktaba#ensure#IsBool(get(a:000, 1, 0))
  let [l:_, l:Funcref, l:bound_args, l:bound_dict] =
      \ typevim#value#DecomposePartial(a:Funcref)
  if !empty(l:bound_dict)
    if l:force_rebind || l:bound_dict is a:obj
      return function(l:Funcref, l:bound_args + l:arglist, a:obj)
    else
      throw maktaba#error#NotAuthorized('Cannot rebind already bound Partial '
            \ . '%s to new object %s (already bound to: %s); set '
            \ . '[force_rebind] to override.',
          \ typevim#object#ShallowPrint(a:Funcref),
          \ typevim#object#ShallowPrint(a:obj),
          \ typevim#object#ShallowPrint(l:bound_dict))
    endif
  endif
  return function(l:Funcref, l:bound_args + l:arglist, a:obj)
endfunction

"""""""""""""""""""""""""""""""""""PRINTING"""""""""""""""""""""""""""""""""""
let s:PRINT_STATE_PROTOTYPE = {
    \ 'Obj': [],
    \ 'starting_indent': 0,
    \ 'seen_objs': [],
    \ 'self_refs': [],
    \ 'max_recursion': 0x7FFFFFFF,
    \ 'cur_recursion': 0,
    \ }
lockvar! s:PRINT_STATE_PROTOTYPE

""
" Construct and return a new PrintState object, used for storing the progress
" of an ongoing PrettyPrint operation.
function! s:PrintState_New() abort
  return deepcopy(s:PRINT_STATE_PROTOTYPE)
endfunction

""
" Construct and return a "child" PrintState object, used for storing the
" progress of an PrettyPrint operation for an element of a parent object.
function! s:PrintState_NewFrom(parent_state, Obj, incr) abort
  let l:new = copy(a:parent_state)
  let l:new.Obj = [a:Obj]
  let l:new.starting_indent += a:incr
  return l:new
endfunction

""
" Return a string of spaces that would indent text by {level} "levels." A
" single indentation level is two spaces. Memoized, for efficiency(?).
" @throws WrongType if {level} is not a number.
function! s:GetIndentBlock(level) abort
  call maktaba#ensure#IsNumber(a:level)
  if a:level <# 0
    throw maktaba#error#BadValue('Gave negative indent level: %d', a:level)
  endif
  if a:level >=# len(s:indent_blocks)
    for l:new_level in range(len(s:indent_blocks), a:level)
      let l:to_add = s:indent_blocks[l:new_level - 1] . s:block
      call add(s:indent_blocks, l:to_add)
    endfor
  endif
  return s:indent_blocks[a:level]
endfunction
let s:block = '  '
let s:indent_blocks = [
    \ '',
    \ '  ',
    \ '    ',
    \ '      ',
    \ '        ',
    \ '          ',
    \ '            ',
    \ '              ',
    \ '                ',
    \ '                  ',
    \ ]
""
" Return the string of spaces that would be used to indent a line to {level},
" assuming that indents are two-spaces wide. A {level} of 0 returns an empty
" string, while a {level} of 2 returns: `'    '`
"
" @throws BadValue if {level} is negative.
" @throws WrongType if {level} is not a number.
function! typevim#object#GetIndentBlock(level) abort  " expose for tests
  if maktaba#ensure#IsNumber(a:level) <# 0
    throw maktaba#error#BadValue(
        \ 'Gave negative indent level to GetIndentBlock: %d', a:level)
  endif
  return s:GetIndentBlock(a:level)
endfunction

""
" Check whether or not `Obj` (a list or a dictionary) has been seen
" before. Takes a {print_state} object as an argument.
"
" If it hasn't, appends `Obj` to `seen_objs` if `Obj` is a collection, and
" returns an empty list. (This is so that the returned value will be `empty()`,
" which can be checked in a conditional statement.)
"
" If it has, appends `Obj` to `self_refs` (if it's not already present) and
" returns a two-element list containing the index of the seen object, and a
" descriptive string, in that order.
" @throws WrongType
function! s:CheckSelfReference(print_state) abort
  let l:Obj = a:print_state.Obj[0]
  let l:seen_objs = a:print_state.seen_objs
  let l:self_refs = a:print_state.self_refs
  if !typevim#value#IsCollection(l:Obj)
    return []
  endif
  call typevim#ensure#IsList(l:seen_objs)
  let l:i = 0 | while l:i <# len(a:print_state.seen_objs)
    let l:seen = l:seen_objs[l:i]
    " if !typevim#value#IsCollection(l:seen)
    "   throw maktaba#error#Failure(
    "       \ 'Seen objects list contained a primitive: '.l:seen)
    " endif
    if l:Obj is l:seen
      let l:j = 0 | while l:j <# len(l:self_refs)
        let l:known_self_ref = l:self_refs[l:j]
        if l:Obj is l:known_self_ref | break | endif
      let l:j += 1 | endwhile
      if l:j ==# len(l:self_refs)  " wasn't in list
        call add(l:self_refs, l:Obj)
      endif
      return [l:j, l:j ? '{self-reference, idx: '.l:j.'}' : '{self-reference}']
    endif
  let l:i += 1 | endwhile
  " you have not been seen
  call add(l:seen_objs, l:Obj)
  return []
endfunction

""
" Exactly the same as function(s:PrettyPrintDict), but prepends 'OBJECT: ' to
" the pretty-print output.
function! s:PrettyPrintObject(...) abort
  return 'OBJECT: '.s:StripLeadingSpaces(call('<SID>PrettyPrintDict', a:000))
endfunction

""
" Returns a "human-readable" string representation of the given dictionary
" {Obj}, splitting keys and values across multiple lines using newline
" characters (`"\n"`). Values that are themselves dictionaries are printed in
" the same fashion, but indented one additional level.
"
" {starting_indent} is the indentation level of this dictionary; it controls
" how many spaces are prepended to the start of each line. A "top-level"
" dictionary is printed from an indentation level of zero; key-value pairs
" within that dictionary print with an indentation level of one; nested
" dictionaries will have an indentation level of two, and so on.
"
" {seen_objs} is a list of collections (lists and dictionaries) that have been
" "seen before," used to avoid infinitely recursing into self-referencing
" collections. See @function(CheckSelfReference).
"
" {self_refs} is a list of "known" self-referencing objects, also used to
" avoid infinite recursion. See @function(CheckSelfReference).
"
" @throws WrongType
function! s:PrettyPrintDict(print_state) abort
  let l:Obj       = typevim#ensure#IsDict(a:print_state.Obj[0])
  let l:seen_objs = typevim#ensure#IsList(a:print_state.seen_objs)
  let l:self_refs = typevim#ensure#IsList(a:print_state.self_refs)
  let l:starting_indent = maktaba#ensure#IsNumber(a:print_state.starting_indent)

  let l:starting_block = s:GetIndentBlock(l:starting_indent)

  if empty(l:Obj)
    return l:starting_block.'{  }'
  endif

  let l:str = l:starting_block."{\n"
  let l:indent_level = l:starting_indent + 1
  let l:indent_block = s:GetIndentBlock(l:indent_level)

  " only sort on keys, not values, so that sort() doesn't recurse into a
  " self-referencing list
  let l:items = sort(items(l:Obj), 'typevim#value#CompareKeys')
  for [l:key, l:Val] in l:items
    let l:str .= l:indent_block.'"'.l:key.'": '

    " check for, handle self-referencing objects
    let l:seen_and_msg = s:CheckSelfReference(
        \ s:PrintState_NewFrom(a:print_state, l:Obj[l:key], 0))
    if !empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    elseif maktaba#value#IsString(l:Val)
      let l:str .= '"'.l:Val.'"'  " don't 'double-wrap' the string
    else
      let l:str .= s:StripLeadingSpaces(
          \ s:PrettyPrintImpl(s:PrintState_NewFrom(a:print_state, l:Val, 1)))
    endif

    let l:str .= ",\n"
  endfor

  return l:str[:-3]."\n".l:starting_block.'}'
endfunction

""
" Returns a string representation of the list {Obj}. Behaves very similarly to
" how vim stringifies lists, except that it explicitly checks for
" self-referencing objects.
"
" {cur_indent} is the current indentation level; it's only passed to this
" function to "remember" it for later invocations of
" @function(s:PrettyPrintDict).
"
" {seen_objs} is a list of collections (lists and dictionaries) that have been
" "seen before," used to avoid infinitely recursing into self-referencing
" collections. See @function(CheckSelfReference).
"
" {self_refs} is a list of "known" self-referencing objects, also used to
" avoid infinite recursion. See @function(CheckSelfReference).
"
" @throws WrongType
function! s:PrettyPrintList(print_state) abort
  let l:Obj       = typevim#ensure#IsList(a:print_state.Obj[0])
  let l:seen_objs = typevim#ensure#IsList(a:print_state.seen_objs)
  let l:self_refs = typevim#ensure#IsList(a:print_state.self_refs)
  let l:cur_indent = maktaba#ensure#IsNumber(a:print_state.starting_indent)

  if empty(l:Obj) | return '[  ]' | endif
  let l:str = '[ '
  for l:Item in l:Obj
    let l:seen_and_msg = s:CheckSelfReference(s:PrintState_NewFrom(a:print_state, l:Item, 0))
    if !empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    else
      let l:str .= s:StripLeadingSpaces(
          \ s:PrettyPrintImpl(s:PrintState_NewFrom(a:print_state, l:Item, 0)))
    endif
    let l:str .= ', '
  endfor
  return l:str[:-3].' ]'  " trim final ', '
endfunction

""
" Return a string of 'shallow-printed' self-referencing items {self_refs},
" if the latter has more than one element; else, return an empty string.
function! s:PrintSelfReferences(self_refs) abort
  call typevim#ensure#IsList(a:self_refs)
  if len(a:self_refs) <=# 1
    return ''
  endif

  let l:str = 'self-referencing objects: [ '
  for l:Obj in a:self_refs
    if !typevim#value#IsCollection(l:Obj)
      throw maktaba#error#Failure(
          \ 'Self-referencing objects list contained a primitive: '.l:Obj)
    endif
    let l:str .= typevim#object#ShallowPrint(l:Obj).', '
  endfor
  return l:str[:-3].' ]'
endfunction

function! s:StripLeadingSpaces(str) abort
  call maktaba#ensure#IsString(a:str)
  return matchstr(a:str, '\S.*$')
endfunction

""
" The actual implementation of function(typevim#object#PrettyPrint), as a
" recursive function. Dispatches to helper functions based on the type of
" {Obj}.
"
" Pretty print `Obj`, given lists of `seen_objects` and known `self_refs`, and
" a current indentation level, used when pretty-printing dicts and
" objects.
"
function! s:PrettyPrintImpl(print_state) abort
  let l:Obj = a:print_state.Obj[0]
  let a:print_state.cur_recursion += 1

  try
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  if a:print_state.cur_recursion >=# a:print_state.max_recursion
    if typevim#value#IsList(l:Obj)
      return '[list]'
    elseif typevim#value#IsValidObject(l:Obj)
      return '{object}'
    elseif typevim#value#IsDict(l:Obj)
      return '{dict}'
    elseif maktaba#value#IsFuncref(l:Obj)
      if typevim#value#IsPartial(l:Obj)
        return "function('".get(l:Obj, 'name').", {partial}')"
      endif
      return "function('".get(l:Obj, 'name')."')"  " IsFuncref, but not Partial
    endif
    return string(l:Obj)
  endif

  if typevim#value#IsDict(l:Obj)
    if typevim#value#IsValidObject(l:Obj)
      return s:PrettyPrintObject(a:print_state)
    else
      return s:PrettyPrintDict(a:print_state)
    endif
  elseif typevim#value#IsList(l:Obj)
    return s:PrettyPrintList(a:print_state)
  elseif maktaba#value#IsFuncref(l:Obj)
    let l:str = "function('".get(l:Obj, 'name')
    if !typevim#value#IsPartial(l:Obj)
      return l:str."')"
    endif
    let [l:_, l:F_, l:bound_args, l:bound_dict] =
        \ typevim#value#DecomposePartial(l:Obj)
    let l:str .= "'"

    if !empty(l:bound_args)
      let l:args_print_state = s:PrintState_NewFrom(a:print_state, l:bound_args, 0)
      let l:seen_and_msg = s:CheckSelfReference(l:args_print_state)
      if !empty(l:seen_and_msg)
        let l:str .= ', ' . l:seen_and_msg[1]
      else
        let l:str .= ', ' . s:PrettyPrintList(l:args_print_state)
      endif
    endif
    if !empty(l:bound_dict)
      let l:dict_print_state = s:PrintState_NewFrom(a:print_state, l:bound_dict, 0)
      let l:seen_and_msg = s:CheckSelfReference(l:dict_print_state)
      " delegate 'is this a dict or object?' to the recursive call
      if !empty(l:seen_and_msg)
        let l:str .= ', '.  l:seen_and_msg[1]
      else
        let l:str .= ', ' . s:PrettyPrintImpl(l:dict_print_state)
      endif
    endif
    return l:str.')'
  else
    return string(l:Obj)
  endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
  catch
    " call s:plugin.logger.Warn(
    "     \ 'Exception thrown while PrettyPrinting: %s', v:exception)
    return printf('ERROR: %s, from: %s', v:exception, v:throwpoint)
  finally
    let a:print_state.cur_recursion -= 1
  endtry
endfunction

""
" Converts the given {Obj} into a string, suitable for error messages and
" debug logging.
"
" If it's already a string, encloses the string in quotes (useful when a
" string is purely whitespace). If it's a TypeVim object or a dictionary, adds
" newlines and tabs to make the resulting string human-readable.
"
" While the returned string can be |echo|ed to the screen as-is, it cannot be
" used directly in functions like |append()| or @function(Buffer.InsertLines),
" as these expect lists of strings where each list element is a single line.
" Use @function(typevim#string#Listify) to convert this function's return
" value into such a list.
"
" Like with @function(typevim#object#ShallowPrint), takes a [max_depth]
" parameter to control how deeply to recurse into a list or a dictionary. When
" recursion terminates due to [max_depth] being met or exceeded, lists, dicts,
" and objects will be printed as `[list]`, `{object}`, and `{dict}`,
" respectively. If [max_depth] is -1, printing will recurse until
" |maxfuncdepth| is exceeded.
"
" Errors that occur during printing will be embedded into the printed output
" so that an error (like |E132|) won't terminate the entire print.
"
" @default max_depth=-1
"
" @throws BadValue if [max_depth] is less than -1.
" @throws MissingFeature if the current version of vim does not support |Partial|s.
" @throws WrongType if [max_depth] is not a number.
function! typevim#object#PrettyPrint(Obj, ...) abort
  " TODO support maktaba enums?
  call typevim#ensure#HasPartials()
  let l:max_depth = maktaba#ensure#IsNumber(get(a:000, 0, -1))

  let l:print_state = s:PrintState_New()
  " note: Obj always goes into a one-element list wrapper, so that dict
  " Funcrefs don't bind to the PrintState object.
  call add(l:print_state.Obj, a:Obj)
  if typevim#value#IsCollection(a:Obj)
    call add(l:print_state.seen_objs, a:Obj)
  endif

  if l:max_depth ==# -1
    " -1 means 'print fully', so don't touch default (very large) value
  elseif l:max_depth <# -1
    throw maktaba#error#BadValue(
        \ 'Gave negative max_depth: %d', l:max_depth)
  else
    let l:print_state.max_recursion = l:max_depth
  endif

  let l:str = s:PrettyPrintImpl(l:print_state)
  let l:self_ref = s:PrintSelfReferences(l:print_state.self_refs)
  return l:str . (empty(l:self_ref) ? '' : ', '.l:self_ref)
endfunction

function! s:ShallowPrintObject(Obj, cur_depth, max_depth) abort
  return 'OBJECT: '.s:ShallowPrintDict(a:Obj, a:cur_depth, a:max_depth)
endfunction

""
" Shallow print the given dictionary {Obj} on a single line.
"
" {cur_depth} and {max_depth} are used for brevity, to avoid recursing too
" deeply into large collections and bloating the output.
" @throws WrongType if {cur_depth} or {max_depth} aren't numbers.
function! s:ShallowPrintDict(Obj, cur_depth, max_depth) abort
  call typevim#ensure#IsDict(a:Obj)
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  if empty(a:Obj)
    return '{  }'
  endif
  let l:str = '{ '
  let l:items = sort(items(a:Obj), 'typevim#value#CompareKeys')
  for [l:key, l:Val] in l:items
    let l:str .= '"'.l:key.'": '
    if maktaba#value#IsString(l:Val)
      let l:str .= '"'.l:Val.'"'
    else
      let l:str .= s:ShallowPrintImpl(l:Val, a:cur_depth + 1, a:max_depth)
    endif
    let l:str .= ', '
  endfor
  return l:str[:-3].' }'
endfunction

""
" Shallow print the given list {Obj} on a single line.
"
" {cur_depth} and {max_depth} are used for brevity, to avoid recursing too
" deeply into large collections and bloating the output.
" @throws WrongType if {cur_depth} or {max_depth} aren't numbers.
function! s:ShallowPrintList(Obj, cur_depth, max_depth) abort
  call typevim#ensure#IsList(a:Obj)
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  if empty(a:Obj)
    return '[  ]'
  endif
  let l:str = '[ '
  for l:Elt in a:Obj
    let l:str .= s:ShallowPrintImpl(l:Elt, a:cur_depth + 1, a:max_depth).', '
  endfor
  return l:str[:-3].' ]'
endfunction

""
" Shallow print the given function reference {Obj}. Output will look similar
" to that produced by `echo`ing a Partial.
"
" {cur_depth} and {max_depth} are used for brevity, to avoid recursing too
" deeply into large collections and bloating the output.
" @throws MissingFeature if the current version of vim does not support |Partial|s.
" @throws WrongType if {cur_depth} or {max_depth} aren't numbers.
function! s:ShallowPrintFuncref(Obj, cur_depth, max_depth) abort
  call typevim#ensure#HasPartials()
  let l:str = "function('".get(a:Obj, 'name')."'"
  if !typevim#value#IsPartial(a:Obj)
    return l:str.')'
  endif
  let [l:_, l:F_, l:bound_args, l:bound_dict] =
      \ typevim#value#DecomposePartial(a:Obj)
  if !empty(l:bound_args)
    let l:str .= ', '
        \ . s:ShallowPrintImpl(l:bound_args, a:cur_depth + 1, a:max_depth)
  endif
  if !empty(l:bound_dict)
    let l:str .= ', '
        \ . s:ShallowPrintImpl(l:bound_dict, a:cur_depth + 1, a:max_depth)
  endif
  return l:str.')'
endfunction

""
" Actual implementation of @function(typevim#object#ShallowPrint), as a
" recursive function. Dispatches to helper functions based on the type of
" {Obj}.
"
" Shallow print {Obj}, recursing from the current recursion depth of
" {cur_depth} down to at most {max_depth} levels of recursion.
" @throws WrongType if {cur_depth} or {max_depth} aren't numbers.
function! s:ShallowPrintImpl(Obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  if !(typevim#value#IsCollection(a:Obj) || maktaba#value#IsFuncref(a:Obj))
    return string(a:Obj)
  endif
  if a:cur_depth ==# a:max_depth
    if typevim#value#IsList(a:Obj)
      return '[list]'
    elseif typevim#value#IsValidObject(a:Obj)
      return '{object}'
    elseif typevim#value#IsDict(a:Obj)
      return '{dict}'
    elseif typevim#value#IsPartial(a:Obj)
      return "function('".get(a:Obj, 'name').", {partial}')"
    else  " IsFuncref, but not Partial
      return "function('".get(a:Obj, 'name')."')"
    endif
  elseif a:cur_depth <# a:max_depth
    if typevim#value#IsList(a:Obj)
      return s:ShallowPrintList(a:Obj, a:cur_depth, a:max_depth)
    elseif typevim#value#IsValidObject(a:Obj)
      return s:ShallowPrintObject(a:Obj, a:cur_depth, a:max_depth)
    elseif typevim#value#IsDict(a:Obj)
      return s:ShallowPrintDict(a:Obj, a:cur_depth, a:max_depth)
    else  " IsFuncref
      return s:ShallowPrintFuncref(a:Obj, a:cur_depth, a:max_depth)
    endif
  else
    throw maktaba#error#Failure(
        \ 'Exceeded recursion limit (%d), current level: %d',
        \ a:max_depth, a:cur_depth)
  endif
endfunction

""
" Like @function(typevim#object#PrettyPrint), but will recurse at most
" [max_depth] levels down into {Obj} if it's a collection or a Partial.
"
" @default max_depth=1
" @throws BadValue  if [max_depth] is negative.
" @throws WrongType if [max_depth] is not a number.
function! typevim#object#ShallowPrint(Obj, ...) abort
  let l:max_depth = maktaba#ensure#IsNumber(get(a:000, 0, 1))
  if l:max_depth <# 0
    throw maktaba#error#BadValue(
        \ 'Gave negative max recursion depth: %d', l:max_depth)
  endif
  return s:ShallowPrintImpl(a:Obj, 0, l:max_depth)
endfunction
