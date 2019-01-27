""
" @dict Doer
" An abstract Doer, for use with @dict(Promise).
"
" In the future, TypeVim may provide Doer's that encapsulate the use of vim
" channels and neovim job control.

let s:typename = 'Doer'

""
" @dict Doer
" Return a new Doer. Will start after a call to its virtual `StartDoing()`
" member function, which takes no arguments.
"
" Note that a Doer will not actually start running until a call to
" @function(Doer.SetCallbacks), to ensure that the job does not finish before
" a success (or error) handler has been attached.
function! typevim#Doer#New() abort
  let l:new = {
      \ 'SetCallbacks': typevim#make#Member('SetCallbacks'),
      \ 'StartDoing': typevim#object#AbstractFunc(s:typename, 'StartDoing', []),
      \ 'Resolve': typevim#object#AbstractFunc(
          \ s:typename, 'Resolve_not_yet_set', ['Val']),
      \ 'Reject': typevim#object#AbstractFunc(
          \ s:typename, 'Reject_not_yet_set', ['Val']),
      \ }
  return typevim#make#Class(l:new)
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" @dict Doer
" Set {Resolve} and {Reject} callbacks on this Doer, to be called when this
" Doer resolves or rejects after doing its assigned task.
function! typevim#Doer#SetCallbacks(Resolve, Reject) dict abort
  call s:CheckType(l:self)
  let l:self['Resolve'] = a:Resolve
  let l:self['Reject'] = a:Reject
  call l:self.StartDoing()
endfunction
