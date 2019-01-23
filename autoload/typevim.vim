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
" If it has, returns a two-element list containing the index of the seen
" object, and a descriptive string, in that order.
" @throws WrongType
" @private
function! s:CheckSelfReference(obj, seen_objects) abort
  if !(maktaba#value#IsList(a:obj) || maktaba#value#IsDict(a:obj))
    return []
  endif
  call maktaba#ensure#IsList(a:seen_objects)
  let l:i = 0 | while l:i <# len(a:seen_objects)
    let l:seen = a:seen_objects[l:i]
    if !maktaba#value#IsCollection(l:seen)
      throw maktaba#error#Failure(
          \ 'Seen objects list contained a primitive: '.l:seen)
    endif
    if l:seen is a:obj
      return [l:i, 'self-reference, idx: '.l:i]
    endif
  let l:i += 1 | endwhile
  " you have not been seen
  call add(a:seen_objects, l:seen)
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
" @usage s:PrettyPrintDict {obj} [starting_indent] [seen_objs]
" @private
function! s:PrettyPrintDict(obj, ...) abort
  call maktaba#ensure#IsDict(a:obj)
  let a:starting_indent = maktaba#ensure#IsNumber(get(a:000, 0, 0))
  let l:seen_objs = maktaba#ensure#IsList(get(a:000, 1, [a:obj]))

  let l:str = s:GetIndentBlock(a:starting_indent)."{\n"
  let l:indent_level = a:starting_indent + 1
  let l:indent_block = s:GetIndentBlock(l:indent_level)

  for [l:key, l:val] in items(a:obj)
    let l:str .= l:indent_block.'"'.l:key.'": '

    " check for, handle self-referencing objects
    let l:seen_and_msg = s:CheckSelfReference(l:val, l:seen_objs)
    if empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    else
      let l:str .= typevim#PrettyPrint(l:val, l:seen_objs)
    endif

    let l:str .= ",\n"
  endfor

  return l:str
endfunction

""
" @usage s:PrettyPrintList {obj} [seen_objs]
" @private
function! s:PrettyPrintList(obj, ...) abort
  call maktaba#ensure#IsList(a:obj)
  let l:seen_objs = maktaba#ensure#IsList(get(a:000, 0, [a:obj]))
  if empty(a:obj) | return '[  ]' | endif
  let l:str = '[ '
  for l:item in a:obj
    let l:seen_and_msg = s:CheckSelfReference(l:item, l:seen_objs)
    if !empty(l:seen_and_msg)
      let l:str .= l:seen_and_msg[1]
    else
      let l:str .= s:PrettyPrintImpl(l:item, l:seen_objs)
    endif
    let l:str .= ', '
  endfor
  return l:str[:-3].' ]'  " trim final ', '
endfunction

""
" Return a string of 'shallow-printed' self-referencing items {seen_objects},
" if the latter is has more than one element; else, return an empty string.
" @private
function! s:PrintSelfReferences(seen_objects) abort
  call maktaba#ensure#IsList(a:seen_objects)
  if empty(a:seen_objects) || len(a:seen_objects) ==# 1
    return ''
  endif

  let l:str = 'self-referencing objects: [ '
  for l:obj in a:seen_objects
    if !maktaba#value#IsCollection(l:obj)
      throw maktaba#error#Failure(
          \ 'Seen objects list contained a primitive: '.l:obj)
    endif
    let l:str .= typevim#ShallowPrint(l:obj).', '
  endfor
  return l:str[:-3].' ]'
endfunction

function! s:PrettyPrintImpl(obj, seen_objects) abort
  call maktaba#ensure#IsList(a:seen_objects)
  if maktaba#value#IsDict(a:obj)
    if typevim#value#IsValidObject(a:obj)
      return s:PrettyPrintObject(a:obj, 0, a:seen_objects)
    else
      return s:PrettyPrintDict(a:obj, 0, a:seen_objects)
    endif
  elseif maktaba#value#IsList(a:obj)
    return s:PrettyPrintList(a:obj, a:seen_objects)
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
  let l:str = s:PrettyPrintImpl(a:obj, l:seen_objs)
  let l:self_ref = s:PrintSelfReferences(l:seen_objs)
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
  for [l:key, l:val] in a:obj
    let l:str .= '"'.l:key.'": '
    let l:str .= s:ShallowPrintImpl(l:val, a:cur_depth + 1, a:max_depth)
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
    let l:str .= s:ShallowPrintImpl(l:elt, a:cur_depth + 1, a:max_depth)
  endfor
  return l:str[:-3].' ]'
endfunction

function! s:ShallowPrintImpl(obj, cur_depth, max_depth) abort
  call maktaba#ensure#IsNumber(a:cur_depth)
  call maktaba#ensure#IsNumber(a:max_depth)
  if !maktaba#value#IsCollection(a:obj)
    return string(a:obj)
  endif
  if a:cur_depth ==# a:max_depth
    if maktaba#value#IsList(a:obj)
      return '[list]'
    elseif typevim#value#IsValidObject(a:obj)
      return '{object}'
    else
      return '{dict}'
    endif
  elseif a:cur_depth <# a:max_depth
    if maktaba#value#IsList(a:obj)
      return s:ShallowPrintList(a:obj, a:cur_depth + 1, a:max_depth)
    elseif typevim#value#IsValidObject(a:obj)
      return s:ShallowPrintObject(a:obj, a:cur_depth + 1, a:max_depth)
    else
      return s:ShallowPrintDict(a:obj, a:cur_depth + 1, a:max_depth)
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
