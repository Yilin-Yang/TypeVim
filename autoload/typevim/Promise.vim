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
" @function typevim#Promise#New([Doer])
" Return a new Promise that will be fulfilled (or broken) by a given [Doer]
" object, if provided.
"
" The [Doer] will be initialized (through a call to its `SetCallbacks` method)
" with two Funcrefs: as with JavaScript Promises, these are `Resolve` and
" `Reject`.
"
" The `Resolve` Funcref, when called by the [Doer], will fulfill ("resolve")
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
"   function! typevim#Promise#NewDoer) abort
"     " ...
"     try
"       Doer.SetCallbacks(self.Resolve, self.Reject)
"     catch TooManyArguments
"       Doer.SetCallbacks(self.Resolve)
"     endtry
"     " ...
" <
"
" Note that, unlike JavaScript, [Doer] is an actual object, rather than a
" function. This is meant for convenience; [Doer] is likely to have other
" member functions that it will pass (as callback functions) to, e.g. neovim's
" |jobstart()| function.
"
" If no [Doer] is provided, then the Promise will only resolve or reject
" through explicit calls to @function(Promise.Resolve) and
" @function(Promise.Reject).
"
" @throws BadValue if {Doer}'s `SetCallbacks` function does not take either one argument or two arguments, or if {Doer} has no `SetCallbacks` function.
" @throws WrongType if {Doer} is not an object, or if `Doer.SetCallbacks` is not a Funcref.
function! typevim#Promise#New(...) abort
  let a:Doer = typevim#ensure#IsValidObject(get(a:000, 0, typevim#Doer#New()))
  if !has_key(a:Doer, 'SetCallbacks')
    throw maktaba#error#BadValue('Given Doer has no SetCallbacks function: %s',
        \ typevim#object#ShallowPrint(a:Doer, 2))
  elseif !maktaba#value#IsFuncref(a:Doer['SetCallbacks'])
    throw maktaba#error#BadValue(
        \ "Given Doer's SetCallbacks is not a Funcref: %s",
        \ typevim#object#ShallowPrint(a:Doer, 2))
  endif

  " NOTE: __handler_attachments is a list of triples: a Doer, a success handler, and an
  " error handler. The Doer is linked to the Promise constructed and returned by
  " the Promise.Then() or Promise.Catch() function calls.
  let l:new = {
      \ '__doer': a:Doer,
      \ '__state': s:PENDING,
      \ '__value': 0,
      \ '__handler_attachments': [],
      \ '__Clear': typevim#make#Member('__Clear'),
      \ 'Resolve': typevim#make#Member('Resolve'),
      \ 'Reject': typevim#make#Member('Reject'),
      \ 'Then': typevim#make#Member('Then'),
      \ 'Catch': typevim#make#Member('Catch'),
      \ 'State': typevim#make#Member('State'),
      \ 'Get': typevim#make#Member('Get'),
      \ 'HasHandlers': typevim#make#Member('HasHandlers'),
      \ }
  let l:new = typevim#make#Class(s:typename, l:new)
  let l:new.Resolve = typevim#object#Bind(l:new.Resolve, l:new)
  let l:new.Reject = typevim#object#Bind(l:new.Reject, l:new)
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
  call a:self.__Clear()
endfunction

""
" @dict Promise
" @private
" Clear this Promise object's list of success and error handlers.
"
" Intended to trigger vim's garbage collection: success and error handlers are
" likely to be dict-bound Partials, and if those dictionaries were created
" once and then discarded (e.g. "chained" promises returned by
" @function(Promise.Then)), then the Partial success/error handler is the only
" reference-keeping object preventing the dictionary from being
" garbage-collected.
function! typevim#Promise#__Clear() dict abort
  call s:TypeCheck(l:self)
  unlet l:self['__handler_attachments']
  let l:self['__handler_attachments'] = []
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
" with the same value. In either case, this Promise will not resolve
" immediately on this call.
"
" TODO Note that if {Val} returns ITSELF on resolution or rejection, then this
" function will infinitely recurse.
"
" Returns this Promise.
"
" @throws NotAuthorized if this Promise was already resolved or rejected.
function! typevim#Promise#Resolve(Val) dict abort
  call s:TypeCheck(l:self)
  if l:self.State() !=# s:PENDING
    throw maktaba#error#NotAuthorized(
        \ 'Tried to resolve an already %s Promise: %s',
        \ l:self.State(), typevim#object#ShallowPrint(l:self, 2))
  endif
  " reassign this Promise's Doer if the given Val is a Promise
  if typevim#value#IsType(a:Val, s:typename)
    let l:self['__doer'] = a:Val['__doer']
  else
    let l:self['__value'] = a:Val
    let l:self['__state'] = s:FULFILLED
    for l:handlers in l:self['__handler_attachments']
      try
        call typevim#ensure#IsType(l:handlers, 'HandlerAttachment')
      catch /ERROR(WrongType)/
        throw maktaba#error#Failure('Malformed handlers found in Promise: %s ',
            \ typevim#object#ShallowPrint(l:handlers))
      endtry
      call l:handlers.ResolveNextLink(a:Val)
    endfor
    call l:self.__Clear()
  endif
  return l:self
endfunction

""
" @dict Promise
" Break ("reject") this Promise. Calls back all attached error handlers
" with the given {Val}, and updates the @function(Promise.State) of this
" Promise to `"rejected"`.
"
" If this Promise is a "live" Promise (i.e. has user-attached success and/or
" error handlers) and has no "live" child Promises (i.e. no "next link" Promises
" with user-attached handlers) to handle the exception, and this Promise does
" not have any error handlers, throw an ERROR(NotFound) due to the unhandled
" exception. TODO
"
" Note that, if a @dict(Promise) is passed as {Val}, this function will not
" behave like @function(Promise.Resolve): it will not "wait" for {Val} to
" resolve or reject, but will start immediately calling back its error
" handlers with {Val} as its "reason".
"
" Returns this Promise.
"
" @throws NotAuthorized if this Promise was already resolved or rejected.
" @throws NotFound if a valid error handler could not be found.
function! typevim#Promise#Reject(Val) dict abort
  call s:TypeCheck(l:self)
  if l:self.State() !=# s:PENDING
    throw maktaba#error#NotAuthorized(
        \ 'Tried to reject an already %s Promise: %s',
        \ l:self.State(), typevim#object#ShallowPrint(l:self, 2))
  endif
  let l:self['__value'] = a:Val
  let l:self['__state'] = s:BROKEN
  let l:handler_list = l:self['__handler_attachments']
  let l:unhandled_rejection = 0
  for l:handlers in l:handler_list
    try
      call typevim#ensure#IsType(l:handlers, 'HandlerAttachment')
    catch /ERROR(WrongType)/
      throw maktaba#error#Failure('Malformed handlers found in Promise: %s ',
          \ typevim#object#ShallowPrint(l:handlers))
    endtry
    try
      let l:live_promise = l:handlers.RejectNextLink(a:Val)
      let l:no_handler = 0
    catch /ERROR(NotFound): Rejection without an error handler/
      let l:live_promise = l:handlers.GetNextLink().HasHandlers()
      let l:no_handler = 1
    endtry
    if l:no_handler && l:live_promise
      let l:unhandled_rejection = 1
    endif
  endfor
  call l:self.__Clear()
  if l:unhandled_rejection
    call s:ThrowUnhandledReject(a:Val, l:self)
  endif
  return l:self
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
" Returns a "child" Promise that will be fulfilled, or rejected, with the
" value of the given {Resolve} success handler or [Reject] error handler
" respectively, unless [chain] is 0, in which case it will return 0.
"
" @default Reject=a "null" error handler.
" @throws WrongType if {Resolve} or [Reject] are not Funcrefs.
function! typevim#Promise#Then(Resolve, ...) dict abort
  call s:TypeCheck(l:self)
  call maktaba#ensure#IsFuncref(a:Resolve)
  let a:Reject = maktaba#ensure#IsFuncref(get(a:000, 0, s:default_handler))
  let a:chain = maktaba#ensure#IsBool(get(a:000, 1, 1))

  let l:no_error_handler = a:Reject ==# s:default_handler

  if l:no_error_handler
    let l:handlers = typevim#HandlerAttachment#New(a:Resolve)
  else
    let l:handlers = typevim#HandlerAttachment#New(a:Resolve, a:Reject)
  endif
  let l:next_link = typevim#Promise#New(l:handlers)

  " resolve/reject immediately, if necessary
  let l:cur_state = l:self['__state']
  let l:Val = l:self['__value']
  if l:cur_state ==# s:FULFILLED
    call l:next_link.Resolve(l:Val)
    return
  elseif l:cur_state ==# s:BROKEN
    try
      call l:next_link.Reject(l:Val)
    catch /ERROR(NotFound)/  " no error handler
      call s:ThrowUnhandledReject(l:self['__value'], l:self)
    endtry
    return
  endif

  call add(l:self['__handler_attachments'], l:handlers)
  return a:chain ? l:next_link : 0
endfunction

""
" @dict Promise
" Attach an error handler {Reject} to this Promise. If this Promise rejects,
" it will call back {Reject} with the provided value. If it was already
" rejected, it will call {Reject} immediately.
"
" Returns a "child" Promise that will be fulfilled, or
" rejected, with the value of the given {Resolve} success handler or [Reject]
" error handler respectively, unless [chain] is 0, in which case it returns 0.
"
" @default chain=1
function! typevim#Promise#Catch(Reject, ...) dict abort
  call s:TypeCheck(l:self)
  call maktaba#ensure#IsFuncref(a:Reject)
  let a:chain = maktaba#ensure#IsBool(get(a:000, 0, 1))
  return l:self.Then(s:default_handler, a:Reject, a:chain)
endfunction

""
" @dict Promise
" Return the current state of this Promise: `"pending"`, `"resolved"`, or
" `"rejected"`.
function! typevim#Promise#State() dict abort
  call s:TypeCheck(l:self)
  return l:self['__state']
endfunction

""
" @dict Promise
" Return the stored value from this Promise's resolution/rejection.
"
" @throws NotFound if this Resolve has not been resolved or rejected.
function! typevim#Promise#Get() dict abort
  call s:TypeCheck(l:self)
  if l:self['__state'] ==# s:PENDING
    throw maktaba#error#NotFound(
        \ 'Promise has not resolved/rejected and stores no value: %s',
        \ typevim#object#ShallowPrint(l:self, 2))
  endif
  return l:self['__value']
endfunction

""
" @dict Promise
" Return whether or this Promise has handlers of the given [handler_type]:
" either `"success"` or `"error"` If [handler_type] is empty, or not provided,
" then this function will return true if the Promise has any handlers at all.
"
" @throws BadValue if [handler_type] is not an empty string, `"success"`, or `"error"`.
" @throws WrongType if [handler_type] is not a string.
function! typevim#Promise#HasHandlers(...) dict abort
  let a:handler_type = maktaba#ensure#IsString(get(a:000, 0, ''))
  let l:handlers = l:self['__handler_attachments']
  if a:handler_type ==# 'success' || a:handler_type ==# ''
    return !empty(l:handlers)
  elseif a:handler_type ==# 'error'
    for l:handler in l:handlers
      if l:handler.HasErrorHandler()
        return 1
      endif
    endfor
    return 0
  else
    throw maktaba#error#BadValue('Bad [handler_type] (must be "success", '
        \ . '"error", or ""): %s', a:handler_type)
  endif
endfunction
