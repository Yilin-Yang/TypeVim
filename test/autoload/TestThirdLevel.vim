let s:typename = 'TestThirdLevel'

function! TestThirdLevel#New(Val, ...) abort
  let l:set_dtor = get(a:000, 0, 0)
  if exists('g:third_level_dtor_called')
    unlet g:third_level_dtor_called
    unlet g:third_level_dtor_timestamp
  endif
  let l:new = {
      \ }
  let l:base = TestDerived#New(1, 0, 0)
  if l:set_dtor
    return typevim#make#Derived(
        \ s:typename, l:base, l:new, typevim#make#Member('CleanUp'))
  else
    return typevim#make#Derived(s:typename, l:base, l:new)
  endif
endfunction

function! TestThirdLevel#CleanUp() dict abort
  let g:third_level_dtor_called = 1
  let g:third_level_dtor_timestamp = reltimefloat(reltime())
  return 1
endfunction
