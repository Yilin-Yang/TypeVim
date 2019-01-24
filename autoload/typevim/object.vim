""
" @private
function! typevim#object#Destroy() abort dict
  let l:destructors = l:self['DESTRUCTORS']
  let l:i = len(l:destructors) - 1
  while l:i ># -1
    let l:Destructor = l:destructors[l:i]
    call function(l:Destructor, l:self)
    let l:i -= 1
  endwhile
endfunction

"""""""""""""""""""""""""""""""""""PRINTING"""""""""""""""""""""""""""""""""""

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
" @private
function typevim#object#GetIndentBlock(level) abort  " expose for tests
  return s:GetIndentBlock(a:level)
endfunction

""
" Check whether or not {Obj} (a list or a dictionary) has been seen
" before.
"
" If it hasn't, appends {Obj} to {seen_objects} if {Obj} is a collection, and
" returns an empty list. (This is so that the returned value will be `empty()`,
" which can be checked in a conditional statement.)
"
" If it has, appends {Obj} to {self_refs} (if it's not already present) and
" returns a two-element list containing the index of the seen object, and a
" descriptive string, in that order.
" @throws WrongType
function! s:CheckSelfReference(Obj, seen_objects, self_refs) abort
  if !maktaba#value#IsCollection(a:Obj)
    return []
  endif
  call maktaba#ensure#IsList(a:seen_objects)
  let l:i = 0 | while l:i <# len(a:seen_objects)
    let l:seen = a:seen_objects[l:i]
    if !maktaba#value#IsCollection(l:seen)
      throw maktaba#error#Failure(
          \ 'Seen objects list contained a primitive: '.l:seen)
    endif
    if a:Obj is l:seen
      let l:j = 0 | while l:j <# len(a:self_refs)
        let l:known_self_ref = a:self_refs[l:j]
        if a:Obj is l:known_self_ref | break | endif
      let l:j += 1 | endwhile
      if l:j ==# len(a:self_refs)  " wasn't in list
        call add(a:self_refs, a:Obj)
      endif
      return [l:j, l:j ? '{self-reference, idx: '.l:j.'}' : '{self-reference}']
    endif
  let l:i += 1 | endwhile
  " you have not been seen
  call add(a:seen_objects, a:Obj)
  return []
endfunction

""
" Exactly the same as function(s:PrettyPrintDict), but prepends 'OBJECT: ' to
" the pretty-print output.
function! s:PrettyPrintObject(...) abort
  return 'OBJECT: '.call('<SID>PrettyPrintDict', a:000)
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
" containers. See @function(CheckSelfReference).
"
" {self_refs} is a list of "known" self-referencing objects, also used to
" avoid infinite recursion. See @function(CheckSelfReference).
"
" @throws WrongType
function! s:PrettyPrintDict(Obj, starting_indent, seen_objs, self_refs) abort
  call maktaba#ensure#IsDict(a:Obj)
  call maktaba#ensure#IsNumber(a:starting_indent)
  call maktaba#ensure#IsList(a:seen_objs)
  call maktaba#ensure#IsList(a:self_refs)

  let l:starting_block = s:GetIndentBlock(a:starting_indent)
  let l:str = l:starting_block."{\n"
  let l:indent_level = a:starting_indent + 1
  let l:indent_block = s:GetIndentBlock(l:indent_level)

  let l:items = sort(items(a:Obj))
  for [l:key, l:Val] in l:items
    let l:str .= l:indent_block.'"'.l:key.'": '

    " check for, handle self-referencing objects
    let l:seen_and_msg = s:CheckSelfReference(l:Val, a:seen_objs, a:self_refs)
    if !empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    elseif maktaba#value#IsString(l:Val)
      let l:str .= '"'.l:Val.'"'  " don't 'double-wrap' the string
    else
      " trim indentation from start of this string before appending
      let l:dict_str = s:PrettyPrintImpl(
          \ l:Val, a:seen_objs, a:self_refs, l:indent_level)
      let l:dict_str = matchstr(l:dict_str, '\S.*$')
      let l:str .= l:dict_str
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
" {seen_objs} is a list of collections (lists and dictionaries) that have been
" "seen before," used to avoid infinitely recursing into self-referencing
" containers. See @function(CheckSelfReference).
"
" {self_refs} is a list of "known" self-referencing objects, also used to
" avoid infinite recursion. See @function(CheckSelfReference).
"
" @throws WrongType
function! s:PrettyPrintList(Obj, seen_objs, self_refs) abort
  call maktaba#ensure#IsList(a:Obj)
  call maktaba#ensure#IsList(a:seen_objs)
  call maktaba#ensure#IsList(a:self_refs)

  if empty(a:Obj) | return '[  ]' | endif
  let l:str = '[ '
  for l:item in a:Obj
    let l:seen_and_msg = s:CheckSelfReference(l:item, a:seen_objs, a:self_refs)
    if !empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    else
      let l:str .= s:PrettyPrintImpl(l:item, a:seen_objs, a:self_refs)
    endif
    let l:str .= ', '
  endfor
  return l:str[:-3].' ]'  " trim final ', '
endfunction

""
" Return a string of 'shallow-printed' self-referencing items {self_refs},
" if the latter has more than one element; else, return an empty string.
function! s:PrintSelfReferences(self_refs) abort
  call maktaba#ensure#IsList(a:self_refs)
  if len(a:self_refs) <=# 1
    return ''
  endif

  let l:str = 'self-referencing objects: [ '
  for l:Obj in a:self_refs
    if !maktaba#value#IsCollection(l:Obj)
      throw maktaba#error#Failure(
          \ 'Self-referencing objects list contained a primitive: '.l:Obj)
    endif
    let l:str .= typevim#object#ShallowPrint(l:Obj).', '
  endfor
  return l:str[:-3].' ]'
endfunction

""
" The actual implementation of function(typevim#object#PrettyPrint).
"
" TODO
" @default cur_indent_level=0
function! s:PrettyPrintImpl(Obj, seen_objects, self_refs, ...) abort
  let a:cur_indent_level = maktaba#ensure#IsNumber(get(a:000, 0, 0))
  call maktaba#ensure#IsList(a:seen_objects)
  if maktaba#value#IsDict(a:Obj)
    if typevim#value#IsValidObject(a:Obj)
      return s:PrettyPrintObject(
          \ a:Obj, a:cur_indent_level, a:seen_objects, a:self_refs)
    else
      return s:PrettyPrintDict(
          \ a:Obj, a:cur_indent_level, a:seen_objects, a:self_refs)
    endif
  elseif maktaba#value#IsList(a:Obj)
    return s:PrettyPrintList(a:Obj, a:seen_objects, a:self_refs)
  elseif maktaba#value#IsFuncref(a:Obj)
    let l:str = "function('".get(a:Obj, 'name')
    let l:args_and_dict = typevim#value#DecomposePartial(a:Obj)
    if empty(l:args_and_dict)  " not a Partial
      return l:str."')"
    endif
    let l:str .= "'"

    let l:bound_args = l:args_and_dict[0]
    let l:bound_dict = l:args_and_dict[1]
    if !empty(l:bound_args)
      call add(a:seen_objects, l:bound_args)
      let l:str .= ', '
          \ . s:PrettyPrintList(l:bound_args, a:seen_objects, a:self_refs)
    endif
    if !empty(l:bound_dict)
      " delegate 'is this a dict or object?' to the recursive call
      call add(a:seen_objects, l:bound_dict)
      let l:str .= ', '
          \ . s:PrettyPrintImpl(l:bound_dict, a:seen_objects, a:self_refs)
    endif
    return l:str.')'
  else
    return string(a:Obj)
  endif
endfunction

""
" Converts the given {object} into a string, suitable for error messages and
" debug logging.
"
" If it's already a string, encloses the string in quotes (useful when a
" string is purely whitespace). If it's a TypeVim object or a dictionary, adds
" newlines and tabs to make the resulting string human-readable.
function! typevim#object#PrettyPrint(Obj) abort
  " TODO support maktaba enums?
  let l:seen_objs = []
  if maktaba#value#IsCollection(a:Obj)
    call add(l:seen_objs, a:Obj)
  endif
  let l:known_self_refs = []
  let l:str = s:PrettyPrintImpl(a:Obj, l:seen_objs, l:known_self_refs)
  let l:self_ref = s:PrintSelfReferences(l:known_self_refs)
  return l:str . (empty(l:self_ref) ? '' : ', '.l:self_ref)
endfunction

function! s:ShallowPrintObject(Obj, cur_depth, max_depth) abort
  return 'OBJECT: '.s:ShallowPrintDict(a:Obj, a:cur_depth, a:max_depth)
endfunction

function! s:ShallowPrintDict(Obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsDict(a:Obj)
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  let l:str = '{ '
  let l:items = sort(items(a:Obj))
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

function! s:ShallowPrintList(Obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsList(a:Obj)
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  let l:str = '[ '
  for l:elt in a:Obj
    let l:str .= s:ShallowPrintImpl(l:elt, a:cur_depth + 1, a:max_depth).', '
  endfor
  return l:str[:-3].' ]'
endfunction

function! s:ShallowPrintFuncref(Obj, cur_depth, max_depth) abort
  let l:str = "function('".get(a:Obj, 'name')."'"
  let l:args_and_dict = typevim#value#DecomposePartial(a:Obj)
  if empty(l:args_and_dict)  " not a Partial
    return l:str.')'
  endif
  let l:bound_args = l:args_and_dict[0]
  let l:bound_dict = l:args_and_dict[1]
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

function! s:ShallowPrintImpl(Obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  if !(maktaba#value#IsCollection(a:Obj) || maktaba#value#IsFuncref(a:Obj))
    return string(a:Obj)
  endif
  if a:cur_depth ==# a:max_depth
    if maktaba#value#IsList(a:Obj)
      return '[list]'
    elseif typevim#value#IsValidObject(a:Obj)
      return '{object}'
    elseif maktaba#value#IsDict(a:Obj)
      return '{dict}'
    elseif typevim#value#IsPartial(a:Obj)
      return "function('".get(a:Obj, 'name').", {partial}')"
    else  " IsFuncref, but not Partial
      return "function('".get(a:Obj, 'name')."')"
    endif
  elseif a:cur_depth <# a:max_depth
    if maktaba#value#IsList(a:Obj)
      return s:ShallowPrintList(a:Obj, a:cur_depth, a:max_depth)
    elseif typevim#value#IsValidObject(a:Obj)
      return s:ShallowPrintObject(a:Obj, a:cur_depth, a:max_depth)
    elseif maktaba#value#IsDict(a:Obj)
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
" Like @function(typevim#object#PrettyPrint), but will recurse at most [max_depth]
" layers down into {Obj} if it's a container or a Partial.
"
" @default max_depth=1
" @throws BadValue  if the given depth is negative.
function! typevim#object#ShallowPrint(Obj, ...) abort
  let a:max_depth = maktaba#ensure#IsNumber(get(a:000, 0, 1))
  if a:max_depth <# 0
    throw maktaba#error#BadValue(
        \ 'Gave negative max recursion depth: %d', a:max_depth)
  endif
  return s:ShallowPrintImpl(a:Obj, 0, a:max_depth)
endfunction
