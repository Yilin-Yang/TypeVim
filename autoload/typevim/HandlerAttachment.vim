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
      \ '__next_link': {},
      \ 'StartDoing': typevim#make#Member('StartDoing'),
      \ 'HandleResolve': typevim#make#Member('HandleResolve'),
      \ 'HandleReject': typevim#make#Member('HandleReject'),
      \ 'ClearReferences': typevim#make#Member('ClearReferences'),
      \ 'GetNextLink': typevim#make#Member('GetNextLink'),
      \ 'HasErrorHandler': typevim#make#Member('HasErrorHandler'),
      \ }
  let l:new = typevim#make#Derived(s:typename, typevim#Doer#New(), l:new)
  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! typevim#HandlerAttachment#StartDoing() dict abort
  call s:CheckType(l:self)
  let l:promise_backref = get(l:self.Resolve, 'dict')
  let l:self['__next_link'] = l:promise_backref
endfunction

""
" @private
" Call the stored success handler with the given {Val}. Resolve the "next
" link" in the Promise chain with the return value of the success handler; if
" the success handler throws an exception, reject the "next link" with the
" value of the exception.
"
" Returns whether or not the next link Promise is "live," i.e. whether it had
" attached handlers.
"
" @throws NotFound if no "next link" Promise backreference is set.
function! typevim#HandlerAttachment#HandleResolve(Val) dict abort
  call s:CheckType(l:self)
  try
    let l:Returned = l:self['__Success_handler'](a:Val)
    call l:self.Resolve(l:Returned)
  catch  " success handler failed somehow; propagate the error
    call l:self.Reject(v:exception)
  endtry
  let l:backref = l:self.GetNextLink()
  return l:backref._HadHandlers()
endfunction

""
" @private
" Call the stored error handler with the given {Val}. If the stored error
" handler doesn't exist, throw an ERROR(NotFound) exception and reject the
" "next link" in the Promise chain with the given {Val}; if the stored
" error handler throws an exception, reject the "next link" in the Promise
" chain with the value of that exception; if the stored error handler returns
" without issue, resolve the next link in the Promise chain with its return
" value.
"
" Returns whether or not the next link Promise is "live," i.e. whether it had
" attached handlers.
"
" @throws NotFound if no error handler was attached, or if no "next link" Promise backreference is set.
function! typevim#HandlerAttachment#HandleReject(Val) dict abort
  call s:CheckType(l:self)
  let l:Handler = l:self['__Error_handler']
  if l:Handler ==# s:default_handler
    call l:self.Reject(a:Val)
    throw maktaba#error#NotFound(
        \ 'Rejection without an error handler: %s', a:Val)
  else
    try
      let l:Returned = l:Handler(a:Val)
      call l:self.Resolve(l:Returned)
    catch  " error handler failed somehow; propagate the error
      call l:self.Reject(v:exception)
    endtry
  endif
  let l:backref = l:self.GetNextLink()
  return l:backref._HadHandlers()
endfunction

""
" @private
" Delete backreferences to the owner Promise (the "next link" in the chain).
function! typevim#HandlerAttachment#ClearReferences() dict abort
  call s:CheckType(l:self)
  unlet l:self.Resolve
  unlet l:self.Reject
  unlet l:self['__next_link']
  let l:self.Resolve = s:default_handler
  let l:self.Reject = s:default_handler
  let l:self['__next_link'] = {}
endfunction

""
" @private
" Returns a backreference to the "next link" Promise. Throws
function! typevim#HandlerAttachment#GetNextLink() dict abort
  call s:CheckType(l:self)
  if empty(l:self['__next_link'])
    throw maktaba#error#NotFound(
        \ 'No backreference set on this HandlerAttachment: %s',
        \ typevim#object#ShallowPrint(l:self))
  endif
  return l:self['__next_link']
endfunction

""
" @private
" Returns 1 if this HandlerAttachment was provided with an error handler on
" construction.
function! typevim#HandlerAttachment#HasErrorHandler() dict abort
  call s:CheckType(l:self)
  return l:self['__Error_handler'] !=# s:default_handler
endfunction
