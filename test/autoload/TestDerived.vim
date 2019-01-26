let s:typename = 'TestDerived'

function! TestDerived#New(set_base_dtor, try_clobber, enable_clobber) abort
  call maktaba#ensure#IsBool(a:set_base_dtor)
  call maktaba#ensure#IsBool(a:try_clobber)
  call maktaba#ensure#IsBool(a:enable_clobber)

  let l:new = {
      \ 'GetVal': typevim#PrefixFunc('GetVal'),
      \ 'SmallVirtual': typevim#object#AbstractFunc(
          \ s:typename, 'BasicVirtual', ['foo']),
      \ 'MediumVirtual': typevim#object#AbstractFunc(
          \ s:typename, 'MediumVirtual', ['foo', 'boo', '[roo]']),
      \ 'BigVirtual': typevim#object#AbstractFunc(
          \ s:typename, 'BigVirtual', ['foo', 'boo', '[roo]', '...']),
      \ }

  if a:try_clobber
    let l:new['__val'] = '-1010'
  endif

  if a:set_base_dtor
    let l:parent = TestBase#New(6.28, { -> 1})
  else
    let l:parent = TestBase#New(6.28)
  endif

  return typevim#make#Derived(
      \ s:typename, l:parent, l:new, { -> 1}, a:enable_clobber)
endfunction

function! TestDerived#GetVal() dict abort
  call typevim#ensure#IsType(l:self, s:typename)
  return 'overridden'
endfunction
