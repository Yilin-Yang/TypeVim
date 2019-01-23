
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

function! s:PrettyPrintObject(obj) abort
endfunction

function! s:PrettyPrintDict(obj, ...) abort
  let a:starting_indent = 0
  let l:str = s:GetIndentBlock(a:starting_indent)."dict: {\n"
  let l:indent_level = a:starting_indent + 1
  let l:indent_block = s:GetIndentBlock(l:indent_level)
  for [l:key, l:val] in items(a:obj)
    let l:str .= l:indent_block.'"'.l:key.'": '
    if maktaba#value#IsDict(l:val)
      if typevim#value#IsValidObject(l:val)
        let l:str .= s:PrettyPrintObject()
      endif
    endif

  endfor
endfunction

""
" Converts the given {object} into a string, suitable for error messages and
" debug logging.
"
" If it's already a string, encloses the string in quotes
" (useful when a string is purely whitespace). If it's a typevim object,
" adds newlines and tabs to make the resulting string human-readable.
function! typevim#PrettyPrint(obj) abort
  " TODO support maktaba enums?
  if maktaba#value#IsDict(a:obj)
    if typevim#value#IsValidObject(a:obj)
      return s:PrettyPrintObject(a:obj)
    endif
    return s:PrettyPrintDict(a:obj)
  elseif maktaba#value#IsList(a:obj)
    if empty(a:obj) | return '[  ]' | endif
    let l:str = '[ '
    for l:item in a:obj
      let l:str .= typevim#PrettyPrint(l:item).', '
    endfor
    return l:str[:-3].' ]'  " trim final ', '
  else
    return string(a:obj)
  endif
endfunction
