""
" Information about the attachment of handlers to a Promise, e.g. through a
" call to @function(Promise.Then) or @function(Promise.Catch). Stores a
" success handler, (optionally) an error handler, and also acts as a Doer that
" may resolve/reject the Promise returned by @function(Promise.Then) or
" @function(Promise.Catch).
"
" Enables "Promise chaining." On resolution, passes the return value of the
" success handler to the "next link" Promise; on rejection, passes the return
" value of the error handler to the "next link" Promise.

let s:typename = 'HandlerAttachment'
let s:default_handler = { -> 0}

""
" @private
" @usage {Success_handler} [Error_handler]
function! typevim#HandlerAttachment#New(Success_handler, ...) abort
  call maktaba#ensure#IsFuncref(a:Success_handler)
  let a:Error_handler = maktaba#ensure#IsFuncref(get(a:000, 0, s:default_handler))
  let l:new = {
      \ '__Success_handler': a:Success_handler,
      \ '__Error_handler': a:Error_handler,
      \ 'StartDoing': typevim#make#Member('StartDoing'),
      \ 'ResolveNextLink': typevim#make#Member('ResolveNextLink'),
      \ 'RejectNextLink': typevim#make#Member('RejectNextLink'),
      \ }
  let l:new = typevim#make#Derived(s:typename, typevim#Doer#New(), l:new)
  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! typevim#HandlerAttachment#StartDoing() dict abort
  call s:CheckType(l:self)
endfunction

""
" @private
" Call the stored success handler with the given {Val}. Resolve the "next
" link" in the Promise chain with the return value of the success handler.
function! typevim#HandlerAttachment#ResolveNextLink(Val) dict abort
  call s:CheckType(l:self)
  let l:Returned = l:self['__Success_handler'](a:Val)
  call l:self.Resolve(l:Returned)
endfunction

""
" @private
" Call the stored error handler with the given {Val}. Reject the "next
" link" in the Promise chain with the return value of the error handler, or
" throw an exception if none was attached..
"
" @throws NotFound if no error handler was attached.
function! typevim#HandlerAttachment#RejectNextLink(Val) dict abort
  call s:CheckType(l:self)
  let l:Handler = l:self['__Error_handler']
  if l:Handler ==# s:default_handler
    throw maktaba#error#NotFound('No attached error handler')
  endif
  let l:Returned = l:Handler(a:Val)
  call l:self.Reject(l:Returned)
endfunction
