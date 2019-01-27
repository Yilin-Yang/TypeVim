""
" @dict Promise
" A JavaScript-style Promise datatype for handling asynchronous operations.
" @dict(Promise) is meant to very roughly mimic JavaScript Promise objects in
" usage and interface.
"
" One notable departure from the JavaScript Promise interface is that
" @dict(Promise) tries to adhere to the Google VimScript style guide, so its
" member functions are written in UpperCamelCase.
"
" Because VimScript itself is entirely singlethreaded, Promise is only useful
" when used with asynchronous operations, like asynchronous jobs and remote
" procedure calls from neovim remote plugins.

let s:typename = 'Promise'

let s:PENDING = 'pending'
let s:FULFILLED = 'resolved'
let s:BROKEN = 'rejected'

let s:default_handler = { -> 0}

""
" @dict Promise
" Return a new Promise that will be fulfilled (or broken) by a given {Doer}
" object.
"
" The {Doer} will be initialized (through a call to its `SetCallbacks` method)
" with two Funcrefs: as with JavaScript Promises, these are `Resolve` and
" `Reject`.
"
" The `Resolve` Funcref, when called by the {Doer}, will fulfill ("resolve")
" this Promise with the passed value (e.g. `Resolve("foo")` will pass `"foo"`
" to all attached success handlers).
"
" The (optional) `Reject` Funcref, when called, will break ("reject") this
" Promise with the passed value (e.g. `Reject("foo")` will pass `"foo"` to
" all attached error handlers).
"
" `Reject` is optional in that the `Doer.SetCallbacks` function may take
" either one Funcref as an argument (`Resolve`), or two (`Resolve` and
" `Reject`). @dict(Promise) detects this automatically:
" >
"   " (pseudocode, not actual implementation)
"   function! typevim#Promise#New(Doer) abort
"     " ...
"     try
"       Doer.SetCallbacks(self.Resolve, self.Reject)
"     catch TooManyArguments
"       Doer.SetCallbacks(self.Resolve)
"     endtry
"     " ...
" <
"
" Note that, unlike JavaScript, {Doer} is an actual object, rather than a
" function. This is meant for convenience; {Doer} is likely to have other
" member functions that it will pass (as callback functions) to, e.g. neovim's
" |jobstart()| function.
"
" @throws BadValue if {Doer}'s `SetCallbacks` function does not take either one argument or two arguments, or if {Doer} has no `SetCallbacks` function.
" @throws WrongType if {Doer} is not an object, or if `Doer.SetCallbacks` is not a Funcref.
function! typevim#Promise#New(Doer) abort
  call typevim#ensure#IsValidObject(a:Doer)
  if !has_key(a:Doer, 'SetCallbacks')
    throw maktaba#error#BadValue('Given Doer has no SetCallbacks function: %s',
        \ typevim#object#ShallowPrint(a:Doer, 2))
  elseif !maktaba#value#IsFuncref(a:Doer['SetCallbacks'])
    throw maktaba#error#BadValue(
        \ "Given Doer's SetCallbacks is not a Funcref: %s",
        \ typevim#object#ShallowPrint(a:Doer, 2))
  endif

  " NOTE: __handlers is a list of pairs: a success handler, and an error
  " handler. The latter being empty, on a rejection, means that this Promise
  " will complain of an unhandled rejection (by throwing an exception).
  let l:new = {
      \ '__doer': a:Doer,
      \ '__state': s:PENDING,
      \ '__value': 0,
      \ '__handlers': [],
      \ 'Resolve': typevim#make#Member('Resolve'),
      \ 'Reject': typevim#make#Member('Reject'),
      \ 'Then': typevim#make#Member('Then'),
      \ 'Catch': typevim#make#Member('Catch'),
      \ 'State': typevim#make#Member('State'),
      \ }
  let l:new = typevim#make#Class(s:typename, l:new)
  let l:new.Resolve = typevim#object#bind(l:new.Resolve, l:new)
  let l:new.Reject = typevim#object#bind(l:new.Reject, l:new)
  try
    try
      call a:Doer.SetCallbacks(l:new.Resolve, l:new.Reject)
    catch /E118/  " Too many arguments
      call a:Doer.SetCallbacks(l:new.Resolve)
    catch /E119/  " Not enough arguments
      throw maktaba#error#BadValue('SetCallbacks on Doer has bad function '
            \ . 'signature (too many parameters): %s',
          \ typevim#object#ShallowPrint(a:Doer, 2))
    endtry
  catch /E118/  " Too many arguments
    throw maktaba#error#BadValue('SetCallbacks on Doer has bad function '
          \ . 'signature (takes no parameters): %s',
        \ typevim#object#ShallowPrint(a:Doer, 2))
  endtry
  return l:new
endfunction

function! s:TypeCheck(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! s:ThrowUnhandledReject(Val, self) abort
  throw maktaba#error#NotFound('Unhandled Promise rejection; rejected with '
        \ . 'reason: %s, inside of Promise: %s',
      \ typevim#object#ShallowPrint(a:Val, 2),
      \ typevim#object#ShallowPrint(a:self, 2))
endfunction

""
" @dict Promise
" Fulfill ("resolve") this Promise. Calls back all attached success handlers
" with the given {Val}, and updates the @function(Promise.State) of this
" Promise to `"resolved"`.
"
" If the given {Val} is, itself, a @dict(Promise), then this Promise will
" "follow" that Promise, i.e. if {Val} resolves, then this Promise will
" resolve with the same value; if {Val} rejects, then this Promise will reject
" with the same value. Note that if {Val} returns ITSELF on resolution or
" rejection, then this function will infinitely recurse.
function! typevim#Promise#Resolve(Val) dict abort
  call s:TypeCheck(l:self)
  let l:self['__value'] = a:Val

  if typevim#value#IsType(a:Val, s:typename)
    " is also a Promise
    call a:Val.Then(l:self.Resolve, l:self.Reject)
    return
  endif

  let l:self['__state'] = s:FULFILLED
  for l:Callback in l:self['__success_handlers']
    if !maktaba#value#IsFuncref(l:Callback)
      throw maktaba#error#Failure('Attached success handler in Promise was '
          \ . 'not a Funcref: %s', typevim#object#ShallowPrint(l:Callback))
    endif
    call l:Callback(a:Val)
  endfor
endfunction

""
" @dict Promise
" Break ("reject") this Promise. Calls back all attached error handlers
" with the given {Val}, and updates the @function(Promise.State) of this
" Promise to `"rejected"`.
"
" If, in a previous call to @function(Promise.Then), this Promise was given a
" success handler without a matching error handler, then this Promise will
" (after calling back all attached error handlers) throw an ERROR(NotFound)
" exception due to the unhandled rejection.
"
" Note that, if a @dict(Promise) is passed as {Val}, this function will not
" behave like @function(Promise.Resolve): it will not "wait" for {Val} to
" resolve or reject, but will start immediately calling back its error
" handlers with {Val} as its "reason".
"
" @throws NotFound if an attached success handler did not have a "matched"
" error handler.
function! typevim#Promise#Reject(Val) dict abort
  call s:TypeCheck(l:self)
  let l:self['__value'] = a:Val
  let l:self['__state'] = s:BROKEN
  let l:rejection_unhandled = 0
  for l:handler_pair in l:self['__handlers']
    if len(l:handler_pair) ==# 1  " only a success handler
      let l:rejection_unhandled = 1
      continue
    elseif len(l:handler_pair) !=# 2
      throw maktaba#error#Failure('Invalid handler pair detected in Promise: %s',
          \ typevim#object#ShallowPrint(l:handler_pair))
    endif
    let l:Success = l:handler_pair[0]
    let l:Failure = l:handler_pair[1]
    if !(maktaba#value#IsFuncref(l:Success)
        \ && maktaba#value#ISFuncref(l:Failure))
      throw maktaba#error#Failure('One or more of attached handlers in Promise '
          \ . 'were not Funcrefs: %s, %s',
          \ typevim#object#ShallowPrint(l:Success),
          \ typevim#object#ShallowPrint(l:Failure))
    endif
    call l:Failure(a:Val)
  endfor
  if l:rejection_unhandled
    call s:ThrowUnhandledReject(a:Val, l:self)
  endif
endfunction

""
" @dict Promise
" Attach a success handler {Resolve} and optionally an error handler [Reject]
" to this Promise. If this Promise resolves, it will call back {Resolve}
" with the resolved value. If it rejects, it will call back [Reject], or throw
" an ERROR(NotFound) exception due to an unhandled rejection if no [Reject]
" handler was attached.
"
" If this Promise is already resolved, it will call {Resolve} immediately with
" the resolved value. If it was already rejected, it will call [Reject]
" immediately, or throw an ERROR(NotFound) exception.
"
" It is strongly suggested that a [Reject] handler be provided in calls to
" this function.
"
" @throws WrongType if {Resolve} or [Reject] are not Funcrefs.
function! typevim#Promise#Then(Resolve, ...) dict abort
  call s:TypeCheck(l:self)
  call maktaba#ensure#IsFuncref(a:Resolve)
  let a:Reject = maktaba#ensure#IsFuncref(get(a:000, 0, s:default_handler))
  let l:no_error_handler = a:Reject ==# s:default_handler

  " resolve/reject immediately, if necessary
  let l:cur_state = l:self['__state']
  if l:cur_state ==# s:FULFILLED
    call a:Resolve(l:self['__value'])
    return
  elseif l:cur_state ==# s:BROKEN
    if !l:no_error_handler
      call a:Reject(l:self['__value'])
    else
      call s:ThrowUnhandledReject(l:self['__value'], l:self)
    endif
    return
  endif

  if l:no_error_handler
    let l:handler_pair = [a:Resolve]
  else
    let l:handler_pair = [a:Resolve, a:Reject]
  endif

  call add(l:self['__handlers'], l:handler_pair)
endfunction

""
" @dict Promise
" Attach an error handler {Reject} to this Promise. If this Promise rejects,
" it will call back {Reject} with the provided value. If it was already
" rejected, it will call {Reject} immediately.
function! typevim#Promise#Catch(Reject) dict abort
  call s:TypeCheck(l:self)
  call maktaba#ensure#IsFuncref(a:Reject)
  if l:self['__state'] ==# s:BROKEN
    call a:Reject(l:self['__value'])
    return
  endif
  call add(l:self['__handlers'], [s:default_handler, a:Reject])
endfunction

""
" @dict Promise
" Return the current state of this Promise: `"pending"`, `"resolved"`, or
" `"rejected"`.
function! typevim#Promise#State() dict abort
  call s:TypeCheck(l:self)
  return l:self['__state']
endfunction
