""
" A Doer that handles Promise chaining. Takes in the "parent" @dict(Promise)
" and attaches success and error handlers; when either are triggered,
" ChainDoer "passes" the resolution or rejection on to its "owner" Promise.

let s:typename = 'ChainDoer'

function! typevim#ChainDoer#New(parent_promise) abort
  call typevim#ensure#IsType(a:parent_promise, 'Promise')
  let l:new = {
      \ 'StartDoing': typevim#make#Member('StartDoing'),
      \ 'ParentResolve': typevim#make#Member('ParentResolve'),
      \ 'ParentReject': typevim#make#Member('ParentReject'),
      \ }
  let l:new = typevim#make#Derived(s:typename, typevim#Doer#New(), l:new)
  let l:new.ParentResolve = typevim#object#Bind(l:new.ParentResolve, l:new)
  let l:new.ParentReject = typevim#object#Bind(l:new.ParentReject, l:new)
  call a:parent_promise.Then(l:new.ParentResolve, l:new.ParentReject, 1)
  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! typevim#ChainDoer#StartDoing() dict abort
  call s:CheckType(l:self)
endfunction

""
" @private
" Success handler to be attached to the "parent" Promise. Resolves the "owner"
" Promise with the given {Val}.
function! typevim#ChainDoer#ParentResolve(Val) dict abort
  call s:CheckType(l:self)
  call l:self.Resolve(a:Val)
endfunction

""
" @private
" Error handler to be attached to the "parent" Promise. Rejects the "owner"
" Promise with the given {Val}.
function! typevim#ChainDoer#ParentReject(Val) dict abort
  call s:CheckType(l:self)
  call l:self.Reject(a:Val)
endfunction
