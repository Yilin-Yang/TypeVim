let s:typename = 'TestSelfRef'

function! TestSelfRef#New(Val) abort
  let l:new = {
      \ '__val': a:Val,
      \ 'GetVal': typevim#make#Member('GetVal'),
      \ }
  call typevim#make#Class(s:typename, l:new)
  let l:new.GetVal = typevim#object#Bind(l:new.GetVal, l:new)
  return l:new
endfunction

function! TestSelfRef#GetVal() dict abort
  return l:self.__val
endfunction
