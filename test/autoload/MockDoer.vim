""
" @dict MockDoer
" A @dict(Doer) that allows for external resolution or rejection of a linked
" Promise.
"
" After being used to construct a Promise, MockDoer will have a `Resolve` and
" `Reject` function, both of which are public and can be invoked in a test
" case.
let s:typename = 'MockDoer'
function! MockDoer#New() abort
  let l:new = {
      \ 'StartDoing': typevim#make#Member('StartDoing'),
      \ }
  return typevim#make#Derived(s:typename, typevim#Doer#New(), l:new)
endfunction

function! MockDoer#StartDoing() dict abort
endfunction
