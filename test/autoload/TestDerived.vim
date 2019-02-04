let s:typename = 'TestDerived'

function! TestDerived#New(set_base_dtor, try_clobber, enable_clobber) abort
  call maktaba#ensure#IsBool(a:set_base_dtor)
  call maktaba#ensure#IsBool(a:try_clobber)
  call maktaba#ensure#IsBool(a:enable_clobber)

  let l:new = {
      \ 'GetVal': typevim#make#Member('GetVal'),
      \ 'SmallVirtual': typevim#make#AbstractFunc(
          \ s:typename, 'BasicVirtual', ['foo']),
      \ 'MediumVirtual': typevim#make#AbstractFunc(
          \ s:typename, 'MediumVirtual', ['foo', 'boo', '[roo]']),
      \ 'BigVirtual': typevim#make#AbstractFunc(
          \ s:typename, 'BigVirtual', ['foo', 'boo', '[roo]', '...']),
      \ }

  if a:try_clobber
    let l:new['__val'] = '-1010'
  endif

  if a:set_base_dtor
    let l:parent = TestBase#New(6.28, function('TestBase#CleanUp'))
  else
    let l:parent = TestBase#New(6.28)
  endif

  return typevim#make#Derived(
      \ s:typename, l:parent, l:new,
      \ typevim#make#Member('CleanUp'), a:enable_clobber)
endfunction

function! TestDerived#CleanUp() dict abort
  call typevim#ensure#IsType(l:self, s:typename)
  return 1
endfunction

function! TestDerived#GetVal() dict abort
  call typevim#ensure#IsType(l:self, s:typename)
  return 'overridden'
endfunction
