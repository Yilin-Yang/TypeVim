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
function! s:DefaultHandler(Arg) abort
  return a:Arg
endfunction
let s:default_handler = function('s:DefaultHandler')

let s:FUNC_PREFIX = 'typevim#HandlerAttachment#'
let s:PROTOTYPE = {
    \ 'StartDoing': function(s:FUNC_PREFIX.'StartDoing'),
    \ 'HandleResolve': function(s:FUNC_PREFIX.'HandleResolve'),
    \ 'HandleReject': function(s:FUNC_PREFIX.'HandleReject'),
    \ 'ClearReferences': function(s:FUNC_PREFIX.'ClearReferences'),
    \ 'GetNextLink': function(s:FUNC_PREFIX.'GetNextLink'),
    \ 'HasErrorHandler': function(s:FUNC_PREFIX.'HasErrorHandler'),
    \ }
call typevim#make#Derived(s:typename, typevim#Doer#New(), s:PROTOTYPE)

""
" @private
" @usage {Success_handler} [Error_handler]
function! typevim#HandlerAttachment#New(Success_handler, ...) abort
  call maktaba#ensure#IsFuncref(a:Success_handler)
  let l:Error_handler = maktaba#ensure#IsFuncref(get(a:000, 0, s:default_handler))

  " Store given callback functions in a list, NOT in the l:new dict directly.
  " This way, if the callbacks are unbound [dict] functions, l:self is not
  " implicitly set equal to the wrapping HandlerAttachment object, and calling
  " the function will throw E725.
  let l:new = deepcopy(s:PROTOTYPE)
  call extend(l:new, {
      \ '__success_and_err': [a:Success_handler, l:Error_handler],
      \ '__called_success': 0,
      \ '__called_error': 0,
      \ '__next_link': {},
      \ })
  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! typevim#HandlerAttachment#StartDoing() dict abort
  call s:CheckType(l:self)
  let l:promise_backref = get(l:self.Resolve, 'dict')
  let l:self.__next_link = l:promise_backref
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
  let l:backref = l:self.GetNextLink()
  let l:to_return = l:backref._HadHandlers()

  " call back the success handler exactly once
  if l:self.__called_success | return l:to_return | endif

  try
    let l:self.__called_success = 1
    let l:Returned = l:self.__success_and_err[0](a:Val)
    call l:self.Resolve(l:Returned)
  catch /E725/
    call l:self.Reject(
        \ 'PROVIDED AN UNBOUND DICT FUNCTION AS CALLBACK, '
        \ . 'USE typevim#object#Bind IN CALL TO Then()! '
        \ . v:exception)
  catch  " success handler failed somehow; propagate the error
    call l:self.Reject(
        \ printf('throwpoint: %s, exception: %s', v:throwpoint, v:exception))
  endtry
  return l:to_return
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
  let l:backref = l:self.GetNextLink()
  let l:to_return = l:backref._HadHandlers()

  " call back the error handler exactly once
  if l:self.__called_error | return l:to_return | endif

  let l:Handler = l:self.__success_and_err[1]
  if l:Handler ==# s:default_handler
    call l:self.Reject(a:Val)
    if typevim#VerboseErrors()
        throw maktaba#error#NotFound(
            \ 'Rejection without an error handler: %s',
            \ typevim#object#ShallowPrint(a:Val))
    else
        throw maktaba#error#NotFound('Rejection without an error handler!')
    endif
  else
    try
      let l:Returned = l:Handler(a:Val)
      call l:self.Resolve(l:Returned)
    catch  " error handler failed somehow; propagate the error
      let l:err_msg = 'Exception from '.v:throwpoint.' with text: '.v:exception
      call l:self.Reject(l:err_msg)
    endtry
  endif

  return l:to_return
endfunction

""
" @private
" Delete backreferences to the owner Promise (the "next link" in the chain).
function! typevim#HandlerAttachment#ClearReferences() dict abort
  call s:CheckType(l:self)
  unlet l:self.Resolve
  unlet l:self.Reject
  unlet l:self.__next_link
  let l:self.Resolve = s:default_handler
  let l:self.Reject = s:default_handler
  let l:self.__next_link = {}
endfunction

""
" @private
" Returns a backreference to the "next link" Promise. Throws
function! typevim#HandlerAttachment#GetNextLink() dict abort
  call s:CheckType(l:self)
  if empty(l:self.__next_link)
    throw maktaba#error#NotFound(
        \ 'No backreference set on this HandlerAttachment: %s',
        \ typevim#object#ShallowPrint(l:self))
  endif
  return l:self.__next_link
endfunction

""
" @private
" Returns 1 if this HandlerAttachment was provided with an error handler on
" construction.
function! typevim#HandlerAttachment#HasErrorHandler() dict abort
  call s:CheckType(l:self)
  return l:self.__success_and_err[1] !=# s:default_handler
endfunction
