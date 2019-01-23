" overelaborate memoized function for producing indentation blocks
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
""
" @private
function typevim#GetIndentBlock(level) abort  " expose for tests
  return s:GetIndentBlock(a:level)
endfunction

""
" Check whether or not {obj} (a list or a dictionary) has been seen
" before.
"
" If it hasn't, appends {obj} to {seen_objects} if {obj} is a collection, and
" returns an empty list. (This is so that the returned value will be `empty()`,
" which can be checked in a conditional statement.)
"
" If it has, appends {obj} to {self_refs} (if it's not already present) and
" returns a two-element list containing the index of the seen object, and a
" descriptive string, in that order.
" @throws WrongType
" @private
function! s:CheckSelfReference(obj, seen_objects, self_refs) abort
  if !maktaba#value#IsCollection(a:obj)
    return []
  endif
  call maktaba#ensure#IsList(a:seen_objects)
  let l:i = 0 | while l:i <# len(a:seen_objects)
    let l:seen = a:seen_objects[l:i]
    if !maktaba#value#IsCollection(l:seen)
      throw maktaba#error#Failure(
          \ 'Seen objects list contained a primitive: '.l:seen)
    endif
    if a:obj is l:seen
      let l:j = 0 | while l:j <# len(a:self_refs)
        let l:known_self_ref = a:self_refs[l:j]
        if a:obj is l:known_self_ref | break | endif
      let l:j += 1 | endwhile
      if l:j ==# len(a:self_refs)  " wasn't in list
        call add(a:self_refs, a:obj)
      endif
      return [l:j, l:j ? '{self-reference, idx: '.l:j.'}' : '{self-reference}']
    endif
  let l:i += 1 | endwhile
  " you have not been seen
  call add(a:seen_objects, a:obj)
  return []
endfunction

""
" Exactly the same as function(s:PrettyPrintDict), but prepends 'OBJECT: ' to
" the pretty-print output.
" @usage s:PrettyPrintObject {obj} [starting_indent] [seen_objs]
" @private
function! s:PrettyPrintObject(...) abort
  return 'OBJECT: '.call('<SID>PrettyPrintDict', a:000)
endfunction

""
" @private
function! s:PrettyPrintDict(obj, starting_indent, seen_objs, self_refs) abort
  call maktaba#ensure#IsDict(a:obj)
  call maktaba#ensure#IsNumber(a:starting_indent)
  call maktaba#ensure#IsList(a:seen_objs)
  call maktaba#ensure#IsList(a:self_refs)

  let l:starting_block = s:GetIndentBlock(a:starting_indent)
  let l:str = l:starting_block."{\n"
  let l:indent_level = a:starting_indent + 1
  let l:indent_block = s:GetIndentBlock(l:indent_level)

  for [l:key, l:val] in items(a:obj)
    let l:str .= l:indent_block.'"'.l:key.'": '

    " check for, handle self-referencing objects
    let l:seen_and_msg = s:CheckSelfReference(l:val, a:seen_objs, a:self_refs)
    if !empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    elseif maktaba#value#IsString(l:val)
      let l:str .= '"'.l:val.'"'  " don't 'double-wrap' the string
    else
      let l:str .= s:PrettyPrintImpl(l:val, a:seen_objs, a:self_refs)
    endif

    let l:str .= ",\n"
  endfor

  return l:str[:-3]."\n".l:starting_block.'}'
endfunction

""
" @private
function! s:PrettyPrintList(obj, seen_objs, self_refs) abort
  call maktaba#ensure#IsList(a:obj)
  call maktaba#ensure#IsList(a:seen_objs)
  call maktaba#ensure#IsList(a:self_refs)
  if empty(a:obj) | return '[  ]' | endif
  let l:str = '[ '
  for l:item in a:obj
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
" @private
function! s:PrintSelfReferences(self_refs) abort
  call maktaba#ensure#IsList(a:self_refs)
  if len(a:self_refs) <=# 1
    return ''
  endif

  let l:str = 'self-referencing objects: [ '
  for l:obj in a:self_refs
    if !maktaba#value#IsCollection(l:obj)
      throw maktaba#error#Failure(
          \ 'Self-referencing objects list contained a primitive: '.l:obj)
    endif
    let l:str .= typevim#ShallowPrint(l:obj).', '
  endfor
  return l:str[:-3].' ]'
endfunction

function! s:PrettyPrintImpl(obj, seen_objects, self_refs) abort
  call maktaba#ensure#IsList(a:seen_objects)
  if maktaba#value#IsDict(a:obj)
    if typevim#value#IsValidObject(a:obj)
      return s:PrettyPrintObject(a:obj, 0, a:seen_objects, a:self_refs)
    else
      return s:PrettyPrintDict(a:obj, 0, a:seen_objects, a:self_refs)
    endif
  elseif maktaba#value#IsList(a:obj)
    return s:PrettyPrintList(a:obj, a:seen_objects, a:self_refs)
  elseif maktaba#value#IsFuncref(a:obj)
    let l:str = "function('".get(a:obj, 'name')
    let l:args_and_dict = typevim#value#DecomposePartial(a:obj)
    if empty(l:args_and_dict)  " not a Partial
      return l:str."')"
    endif

    let l:bound_args = l:args_and_dict[0]
    let l:bound_dict = l:args_and_dict[1]
    if !empty(l:bound_args)
      let l:str .= ', '
          \ . s:PrettyPrintImpl(l:bound_args, a:seen_objects, a:self_refs)
    endif
    if !empty(l:bound_dict)
      let l:str .= ', '
          \ . s:PrettyPrintImpl(l:bound_dict, a:seen_objects, a:self_refs)
    endif
    return l:str.')'
  else
    return string(a:obj)
  endif
endfunction

""
" Converts the given {object} into a string, suitable for error messages and
" debug logging.
"
" If it's already a string, encloses the string in quotes (useful when a
" string is purely whitespace). If it's a TypeVim object or a dictionary, adds
" newlines and tabs to make the resulting string human-readable.
function! typevim#PrettyPrint(obj) abort
  " TODO support maktaba enums?
  let l:seen_objs = []
  if maktaba#value#IsCollection(a:obj)
    call add(l:seen_objs, a:obj)
  endif
  let l:known_self_refs = []
  let l:str = s:PrettyPrintImpl(a:obj, l:seen_objs, l:known_self_refs)
  let l:self_ref = s:PrintSelfReferences(l:known_self_refs)
  return l:str . (empty(l:self_ref) ? '' : ', '.l:self_ref)
endfunction

function! s:ShallowPrintObject(obj, cur_depth, max_depth) abort
  return 'OBJECT: '.s:ShallowPrintDict(a:obj, a:cur_depth, a:max_depth)
endfunction

function! s:ShallowPrintDict(obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsDict(a:obj)
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  let l:str = '{ '
  for [l:key, l:val] in items(a:obj)
    let l:str .= '"'.l:key.'": '
    if maktaba#value#IsString(l:val)
      let l:str .= '"'.l:val.'"'
    else
      let l:str .= s:ShallowPrintImpl(l:val, a:cur_depth + 1, a:max_depth)
    endif
    let l:str .= ', '
  endfor
  return l:str[:-3].' }'
endfunction

function! s:ShallowPrintList(obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsList(a:obj)
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  let l:str = '[ '
  for l:elt in a:obj
    let l:str .= s:ShallowPrintImpl(l:elt, a:cur_depth + 1, a:max_depth).', '
  endfor
  return l:str[:-3].' ]'
endfunction

function! s:ShallowPrintFuncref(obj, cur_depth, max_depth) abort
  let l:str = "function('".get(a:obj, 'name')."'"
  let l:args_and_dict = typevim#value#DecomposePartial(a:obj)
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

function! s:ShallowPrintImpl(obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  if !(maktaba#value#IsCollection(a:obj) || maktaba#value#IsFuncref(a:obj))
    return string(a:obj)
  endif
  if a:cur_depth ==# a:max_depth
    if maktaba#value#IsList(a:obj)
      return '[list]'
    elseif typevim#value#IsValidObject(a:obj)
      return '{object}'
    elseif maktaba#value#IsDict(a:obj)
      return '{dict}'
    elseif typevim#value#IsPartial(a:obj)
      return "function('".get(a:obj, 'name').", {partial}')"
    else  " IsFuncref, but not Partial
      return "function('".get(a:obj, 'name')."')"
    endif
  elseif a:cur_depth <# a:max_depth
    if maktaba#value#IsList(a:obj)
      return s:ShallowPrintList(a:obj, a:cur_depth, a:max_depth)
    elseif typevim#value#IsValidObject(a:obj)
      return s:ShallowPrintObject(a:obj, a:cur_depth, a:max_depth)
    elseif maktaba#value#IsDict(a:obj)
      return s:ShallowPrintDict(a:obj, a:cur_depth, a:max_depth)
    else  " IsFuncref
      return s:ShallowPrintFuncref(a:obj, a:cur_depth, a:max_depth)
    endif
  else
    throw maktaba#error#Failure(
        \ 'Exceeded recursion limit (%d), current level: %d',
        \ a:max_depth, a:cur_depth)
  endif
endfunction

""
" Like @function(typevim#PrettyPrint), but will recurse at most [max_depth]
" layers down into {obj} if it's a container.
"
" @usage typevim#ShallowPrint {obj} [max_depth]
" @default max_depth=1
" @throws BadValue  if the given depth is negative.
function! typevim#ShallowPrint(obj, ...) abort
  let a:max_depth = maktaba#ensure#IsNumber(get(a:000, 0, 1))
  if a:max_depth <# 0
    throw maktaba#error#BadValue(
        \ 'Gave negative max recursion depth: %d', a:max_depth)
  endif
  return s:ShallowPrintImpl(a:obj, 0, a:max_depth)
endfunction
