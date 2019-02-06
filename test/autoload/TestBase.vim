let s:typename = 'TestBase'

function! TestBase#New(Val, ...) abort
  let a:Dtor = get(a:000, 0, 0)
  let l:new = {
      \ '__val': a:Val,
      \ 'GetVal': typevim#make#Member('GetVal'),
      \ 'SetVal': typevim#make#Member('SetVal'),
      \ 'StringifyVals': typevim#make#Member('StringifyVals'),
      \ }
  return typevim#make#Class(s:typename, l:new, a:Dtor)
endfunction

function! TestBase#CleanUp() dict abort
  call typevim#ensure#IsType(l:self, s:typename)
  return 1
endfunction

function! TestBase#GetVal() dict abort
  call typevim#ensure#IsType(l:self, s:typename)
  return l:self['__val']
endfunction

function! TestBase#SetVal(Val) dict abort
  call typevim#ensure#IsType(l:self, s:typename)
  let l:self['__val'] = a:Val
endfunction

function! TestBase#StringifyVals(...) dict abort
  return typevim#object#ShallowPrint(a:000)
endfunction
