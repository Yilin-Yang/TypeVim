""
" @dict Promise
" A JavaScript-style Promise datatype for handling asynchronous operations.
" @dict(Promise) is meant to roughly mimic JavaScript Promise objects in
" usage and interface, and is mostly compliant with the Promise/A+ spec.
" Deviations from the spec are noted further below.
"
" Because VimScript itself is entirely singlethreaded, Promise is only useful
" when used with asynchronous operations, like asynchronous jobs and remote
" procedure calls from neovim remote plugins.
"
" @subsection Promise/A+ Differences and Things to Note
" These are listed by section, subsection, and clause, using the specification
" on https://promisesaplus.com as reference.
"
" - 2.2) @dict(Promise) tries to adhere to the Google VimScript style guide, and
"   names its member functions in UpperCamelCase, including
"   @function(Promise.Then). `Promise.then()` is an alias of this function,
"   since Promise/A+ requires that the `then` function be all lowercase.
"
" - 2.2.4) @dict(Promise) does not strictly guarantee that `then()` callbacks
"   will be delayed until the callstack "contains only platform code."
"   Whenever a Promise is resolved or rejected, it passes its attached
"   callbacks to a zero-millisecond |timer| that won't fire until vim is
"   idle, i.e. until the current function has returned, the callstack has
"   cleared, and so on. However, if a function in that callstack |sleep|s,
"   Promise timer callbacks may fire during that sleep interval.
"
" - 2.3.1) When resolving a @dict(Promise) with itself, Promise throws an
"   ERROR(BadValue) instead of an ERROR(WrongType) (`"TypeError"`). This is
"   for better consistency with vim-maktaba, since ERROR(BadValue) better
"   describes the nature of the error.
"
" - 2.3.3) @dict(Promise) offers no special handling when resolved with
"   objects that possess a `then` property, but which are not @dict(Promise)s
"   instances specifically. It will simply pass this object unmodified to its
"   attached success handlers.

let s:typename = 'Promise'

let s:PENDING = 'pending'
let s:FULFILLED = 'fulfilled'
let s:BROKEN = 'rejected'

function! s:DefaultHandler(Val) abort
  return a:Val
endfunction
let s:default_handler = function('s:DefaultHandler')

let s:promise_id = 0

let s:FUNC_PREFIX = 'typevim#Promise#'
let s:PROTOTYPE = {
    \ '__Clear': function(s:FUNC_PREFIX.'__Clear'),
    \ '_HadHandlers': function(s:FUNC_PREFIX.'_HadHandlers'),
    \ 'Resolve': function(s:FUNC_PREFIX.'Resolve'),
    \ 'Reject': function(s:FUNC_PREFIX.'Reject'),
    \ 'Then': function(s:FUNC_PREFIX.'Then'),
    \ 'Catch': function(s:FUNC_PREFIX.'Catch'),
    \ 'State': function(s:FUNC_PREFIX.'State'),
    \ 'Get': function(s:FUNC_PREFIX.'Get'),
    \ '__state': s:PENDING,
    \ '__value': '[no value set]',
    \ '__had_handlers': 0,
    \ '__handler_attachments': [],
    \ }
" set this alias for Promise/A+ 2.2 compliance
let s:PROTOTYPE.then = s:PROTOTYPE.Then
call typevim#make#Class(s:typename, s:PROTOTYPE)

""
" @dict Promise
" @function typevim#Promise#New([Doer])
" Return a new Promise that will be fulfilled (or broken) by a given [Doer]
" object, if provided.
"
" The [Doer] will be initialized (through a call to its `SetCallbacks` method)
" with two Funcrefs: `Resolve` and `Reject`.
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
"   function! typevim#Promise#New(Doer) abort
"     " ...
"     try
"       a:Doer.SetCallbacks(self.Resolve, self.Reject)
"     catch TooManyArguments
"       a:Doer.SetCallbacks(self.Resolve)
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
" @throws BadValue if [Doer]'s `SetCallbacks` function does not take either one argument or two arguments, or if [Doer] has no `SetCallbacks` function.
" @throws WrongType if [Doer] is not an object, or if `Doer.SetCallbacks` is not a Funcref.
function! typevim#Promise#New(...) abort
  if !typevim#value#HasTimerTryCatchPatch()
      \ && (!exists('g:typevim_promise_minversion_ignore')
          \ || !g:typevim_promise_minversion_ignore)
    call maktaba#error#Warn(
        \ 'This version of vim does not include the 8.0.1067 timer patch! '
        \.'TypeVim.Promise resolution or rejection may not work correctly '
        \.'without this feature. (Set g:typevim_promise_minversion_ignore to '
        \.'1 in your .vimrc to silence this warning!)')
    let g:typevim_promise_minversion_ignore = 1
  endif

  if a:0
    let l:Doer = typevim#ensure#IsValidObject(a:1)
    if !has_key(l:Doer, 'SetCallbacks')
      if typevim#VerboseErrors()
        throw maktaba#error#BadValue(
            \ 'Given Doer has no SetCallbacks function: %s',
            \ typevim#object#ShallowPrint(l:Doer, 2))
      else
        throw maktaba#error#BadValue(
            \ 'Given Doer has no SetCallbacks function!')
      endif
    elseif !maktaba#value#IsFuncref(l:Doer['SetCallbacks'])
      if typevim#VerboseErrors()
        throw maktaba#error#BadValue(
            \ "Given Doer's SetCallbacks is not a Funcref: %s",
            \ typevim#object#ShallowPrint(l:Doer, 2))
      else
        throw maktaba#error#BadValue(
            \ "Given Doer's SetCallbacks is not a Funcref!")
      endif
    endif
  else
    let l:Doer = typevim#Doer#New()
  endif

  " NOTE: __handler_attachments is a list of triples: a Doer, a success
  " handler, and an error handler. The Doer is linked to the Promise
  " constructed and returned by the Promise.Then() or Promise.Catch() function
  " calls.
  let s:promise_id += 1
  let l:new = deepcopy(s:PROTOTYPE)
  call extend(l:new, {
      \ '__id': s:promise_id,
      \ '__doer': l:Doer,
      \ })

  let l:new.Resolve = typevim#object#Bind(l:new.Resolve, l:new)
  let l:new.Reject = typevim#object#Bind(l:new.Reject, l:new)
  call typevim#Promise#__SetDoerCallbacks(l:new.Resolve, l:new.Reject, l:Doer)
  return l:new
endfunction

function! s:TypeCheck(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

let g:typevim_unhandled_reject_print_rec_depth = 4
function! s:ThrowUnhandledReject(Val, self) abort
  if typevim#VerboseErrors()
    let l:print_output = typevim#object#PrettyPrint(
        \ a:self, g:typevim_unhandled_reject_print_rec_depth)
    call a:self.__Clear()
    throw maktaba#error#NotFound('Unhandled Promise rejection; rejected with '
          \ . 'reason: %s, inside of Promise: %s',
        \ typevim#object#ShallowPrint(a:Val, 2),
        \ l:print_output)
  else
    throw maktaba#error#NotFound(
        \ 'Unhandled Promise rejection; rejected with reason: %s',
        \ typevim#object#ShallowPrint(a:Val, 2))
  endif
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
" @private
" Set callbacks {Resolve} and {Reject} on the given {Doer}.
" @throws BadValue
" @throws WrongType
function! typevim#Promise#__SetDoerCallbacks(Resolve, Reject, Doer) abort
  try
    try
      call a:Doer.SetCallbacks(a:Resolve, a:Reject)
    catch /E118/  " Too many arguments
      call a:Doer.SetCallbacks(a:Resolve)
    catch /E119/  " Not enough arguments
      if typevim#VerboseErrors()
        throw maktaba#error#BadValue('SetCallbacks on Doer has bad function '
              \ . 'signature (too many parameters): %s',
            \ typevim#object#ShallowPrint(a:Doer, 2))
      else
        throw maktaba#error#BadValue('SetCallbacks on Doer has bad function '
              \ . 'signature (too many parameters)')
      endif
    endtry
  catch /E118/  " Too many arguments
    if typevim#VerboseErrors()
      throw maktaba#error#BadValue('SetCallbacks on Doer has bad function '
            \ . 'signature (takes no parameters): %s',
          \ typevim#object#ShallowPrint(a:Doer, 2))
    else
      throw maktaba#error#BadValue('SetCallbacks on Doer has bad function '
            \ . 'signature (takes no parameters)')
    endif
  endtry
endfunction

""
" @dict Promise
" @private
" Return whether or not success and/or error handlers had been attached to
" this Promise at any point. Used internally to identify "dead" Promises that
" were constructed in calls to @function(Promise.Then), but which presumably
" aren't being used anywhere.
function! typevim#Promise#_HadHandlers() dict abort
  call s:TypeCheck(l:self)
  return l:self.__had_handlers
endfunction

""
" @private
" Call back the given success handlers with the given resolution value.
"
" Meant to be invoked asynchronously, in this case, from a timer with delay
" 0ms. Timers do not "fire" until vim is no longer busy, like during a sleep
" statement, or when vim is waiting for user input. Because executing a
" callstack counts as being "busy," this guarantees that the callback does not
" occur synchronously from inside the stackframe responsible for the
" resolution/rejection.
"
" This is for compliance with Promises/A+ 2.2.4.
function! s:CallbackSuccessHandlers(promise, handler_attachments, Val, timernum) abort
  call s:TypeCheck(a:promise)
  let a:promise.__value = a:Val
  let a:promise.__state = s:FULFILLED
  for l:handlers in a:handler_attachments
    try
      call typevim#ensure#IsType(l:handlers, 'HandlerAttachment')
    catch /ERROR(WrongType)/
      throw maktaba#error#Failure('Malformed handlers found in Promise: %s ',
          \ typevim#object#ShallowPrint(l:handlers))
    endtry
    call l:handlers.HandleResolve(a:Val)
  endfor
  call a:promise.__Clear()
endfunction

""
" @private
" Call back the given error handlers with the given rejection value.
"
" See @function(s:CallbackSuccessHandlers).
function! s:CallbackErrorHandlers(promise, handler_attachments, Val, timernum) abort
  call s:TypeCheck(a:promise)
  let a:promise.__value = a:Val
  let a:promise.__state = s:BROKEN
  let l:handler_list = a:handler_attachments

  let l:live_children_exist = 0
  let l:error_handler_exists = 0
  for l:handlers in l:handler_list
    try
      call typevim#ensure#IsType(l:handlers, 'HandlerAttachment')
    catch /ERROR(WrongType)/
      throw maktaba#error#Failure('Malformed handlers found in Promise: %s ',
          \ typevim#object#ShallowPrint(l:handlers))
    endtry
    try
      let l:live_promise = l:handlers.HandleReject(a:Val)
      let l:was_handled = 1
    catch /ERROR(NotFound): Rejection without an error handler/
      let l:live_promise = l:handlers.GetNextLink()._HadHandlers()
      let l:was_handled = 0
    endtry
    if l:live_promise | let l:live_children_exist  = 1 | endif
    if l:was_handled  | let l:error_handler_exists = 1 | endif
  endfor

  if !l:live_children_exist && !l:error_handler_exists
    call a:promise.__Clear()
    call s:ThrowUnhandledReject(a:Val, a:promise)
  endif

  call a:promise.__Clear()
endfunction

""
" @dict Promise
" Fulfill ("resolve") this Promise. Calls back all attached success handlers
" with the given {Val}, and updates the @function(Promise.State) of this
" Promise to `"fulfilled"`.
"
" If the given {Val} is, itself, a @dict(Promise), then this Promise will
" "follow" that Promise, i.e. if {Val} resolves, then this Promise will
" resolve with the same value; if {Val} rejects, then this Promise will reject
" with the same value. In either case, this Promise will not resolve
" immediately on this call. Note that this will "expunge" this Promise's
" current @dict(Doer), if it has one.
"
" Returns the given {Val}.
"
" @throws BadValue if the given {Val} is the same as this Promise.
" @throws NotAuthorized if this Promise was already resolved or rejected.
function! typevim#Promise#Resolve(Val) dict abort
  call s:TypeCheck(l:self)
  if a:Val is l:self
    if typevim#VerboseErrors()
      throw maktaba#error#BadValue(
          \ 'Tried to resolve a Promise with itself in callstack %s: %s',
          \ expand('<sfile>'), typevim#object#ShallowPrint(a:Val))
    else
      throw maktaba#error#BadValue(
          \ 'Tried to resolve a Promise with itself in callstack %s',
          \ expand('<sfile>'))
    endif
  endif
  if l:self.State() !=# s:PENDING
    if typevim#VerboseErrors()
      throw maktaba#error#NotAuthorized(
          \ 'Tried to resolve an already %s Promise in callstack %s: %s',
          \ l:self.State(), expand('<sfile>'),
          \ typevim#object#ShallowPrint(l:self, 2))
    else
      throw maktaba#error#NotAuthorized(
          \ 'Tried to resolve an already %s Promise in callstack %s',
          \ l:self.State(), expand('<sfile>'))
    endif
  endif
  if typevim#value#IsDict(a:Val) && typevim#value#IsType(a:Val, s:typename)
    " 'disable' the current Doer, if one exists
    " when a Promise is resolved with another Promise, it *must* match that
    " other Promise's state (without resolving 'early', etc.) (A+ Spec, 2.3.2)
    call typevim#Promise#__SetDoerCallbacks(
        \ s:default_handler, s:default_handler, l:self.__doer)

    " resolve/reject immediately if Val is resolved/rejected, or just adopt
    " its same value when it does resolve
    call a:Val.Then(l:self.Resolve, l:self.Reject)
    return a:Val
  else
    call timer_start(0, function(
        \ 's:CallbackSuccessHandlers',
        \ [l:self, l:self.__handler_attachments, a:Val]))
  endif
  return a:Val
endfunction

""
" @dict Promise
" Break ("reject") this Promise. Calls back all attached error handlers
" with the given {Val}, and updates the @function(Promise.State) of this
" Promise to `"rejected"`.
"
" If this Promise has no "live" child Promises (i.e. no "next link" Promises
" with user-attached handlers), AND this Promise does not have any error
" handlers, throws an ERROR(NotFound) due to the unhandled exception.
"
" Note that, if a @dict(Promise) is passed as {Val}, this function will not
" behave like @function(Promise.Resolve): it will not "wait" for {Val} to
" resolve or reject, but will start immediately calling back its error
" handlers with {Val} as its "reason".
"
" Returns the given {Val}.
"
" @throws NotAuthorized if this Promise was already resolved or rejected.
" @throws NotFound if a valid error handler could not be found.
function! typevim#Promise#Reject(Val) dict abort
  call s:TypeCheck(l:self)
  if l:self.State() !=# s:PENDING
    if typevim#VerboseErrors()
      throw maktaba#error#NotAuthorized(
          \ 'Tried to reject an already %s Promise in callstack %s: %s',
          \ l:self.State(), expand('<sfile>'),
          \ typevim#object#ShallowPrint(l:self, 2))
    else
      throw maktaba#error#NotAuthorized(
          \ 'Tried to reject an already %s Promise in callstack %s',
          \ l:self.State(), expand('<sfile>'))
    endif
  endif

  call timer_start(0, function(
      \ 's:CallbackErrorHandlers',
      \ [l:self, l:self.__handler_attachments, a:Val]))

  return a:Val
endfunction

""
" @dict Promise
" Attach a success handler {Resolve} and optionally an error handler [Reject]
" to this Promise. If this Promise resolves, it will call back {Resolve}
" with the resolved value. If it rejects, it will call back [Reject], or throw
" an ERROR(NotFound) exception due to an unhandled rejection if there are no
" [Reject] error handlers "in the chain." (See @function(Promise.Reject).)
"
" If this Promise is already resolved, it will call {Resolve} immediately with
" the resolved value. If it was already rejected, it will call [Reject]
" immediately, or throw an ERROR(NotFound) exception.
"
" It is strongly suggested that a [Reject] handler be provided in calls to
" this function.
"
" If {Resolve} is |v:null|, it will be replaced with a "default" Funcref
" that simply returns (unmodified) whatever value it's given. If [Reject] is
" |v:null|, then the function will behave as if no error handler was given at
" all.
"
" Returns a "child" Promise that will be fulfilled, or rejected, with the
" value of the given {Resolve} success handler or [Reject] error handler
" respectively, unless [chain] is 0, in which case it will return 0.
"
" @default Reject=a "null" error handler
" @default chain=1
" @throws WrongType if {Resolve} or [Reject] are not Funcrefs.
function! typevim#Promise#Then(Resolve, ...) dict abort
  call s:TypeCheck(l:self)
  if maktaba#value#IsFuncref(a:Resolve)
    let l:Resolve = a:Resolve
  elseif a:Resolve is v:null
    let l:Resolve = s:default_handler
  else
    if typevim#VerboseErrors()
      throw maktaba#error#WrongType(
          \ 'Given Resolve is neither a Funcref nor v:null: %s',
          \ typevim#object#ShallowPrint(a:Resolve, 2))
    else
      throw maktaba#error#WrongType(
          \ 'Given Resolve is neither a Funcref nor v:null')
    endif
  endif
  let l:Reject = get(a:000, 0, s:default_handler)
  if maktaba#value#IsFuncref(l:Reject)
    let l:Reject = l:Reject
  elseif l:Reject is v:null
    let l:Reject = s:default_handler
  else
    if typevim#VerboseErrors()
      throw maktaba#error#WrongType(
          \ 'Given Reject is neither a Funcref nor v:null: %s',
          \ typevim#object#ShallowPrint(a:Resolve, 2))
    else
      throw maktaba#error#WrongType(
          \ 'Given Reject is neither a Funcref nor v:null')
    endif
  endif
  let l:chain = maktaba#ensure#IsBool(get(a:000, 1, 1))

  let l:no_error_handler = l:Reject ==# s:default_handler
  if l:no_error_handler
    let l:handlers = typevim#HandlerAttachment#New(l:Resolve)
  else
    let l:handlers = typevim#HandlerAttachment#New(l:Resolve, l:Reject)
  endif
  let l:next_link = typevim#Promise#New(l:handlers)

  let l:self.__had_handlers = 1
  let l:cur_state = l:self.__state
  let l:Val = l:self.__value

  " resolve/reject immediately, if necessary
  if l:cur_state ==# s:FULFILLED
    call timer_start(0, function(
        \ 's:CallbackSuccessHandlers',
        \ [l:self, [l:handlers], l:self.__value]))
  elseif l:cur_state ==# s:BROKEN
    call timer_start(0, function(
        \ 's:CallbackErrorHandlers',
        \ [l:self, [l:handlers], l:self.__value]))
  else
    call add(l:self.__handler_attachments, l:handlers)
  endif

  return l:chain ? l:next_link : 0
endfunction

""
" @dict Promise
" Attach an error handler {Reject} to this Promise. If this Promise rejects,
" it will call back {Reject} with the provided value. If it was already
" rejected, it will call {Reject} immediately.
"
" Returns a "child" Promise that will be fulfilled, or rejected, with the
" given resolved value the return value of the {Reject} error handler
" respectively, unless [chain] is 0, in which case it returns 0.
"
" @default chain=1
function! typevim#Promise#Catch(Reject, ...) dict abort
  call s:TypeCheck(l:self)
  call maktaba#ensure#IsFuncref(a:Reject)
  let l:chain = maktaba#ensure#IsBool(get(a:000, 0, 1))
  return l:self.Then(s:default_handler, a:Reject, l:chain)
endfunction

""
" @dict Promise
" Return the current state of this Promise: `"pending"`, `"fulfilled"`, or
" `"rejected"`.
function! typevim#Promise#State() dict abort
  call s:TypeCheck(l:self)
  return l:self.__state
endfunction

""
" @dict Promise
" Return the stored value/reason from this Promise's resolution/rejection.
"
" @throws NotFound if this Promise has not been resolved or rejected.
function! typevim#Promise#Get() dict abort
  call s:TypeCheck(l:self)
  if l:self.__state ==# s:PENDING
    if typevim#VerboseErrors()
      throw maktaba#error#NotFound(
          \ 'Promise has not resolved/rejected and stores no value: %s',
          \ typevim#object#ShallowPrint(l:self, 2))
    else
      throw maktaba#error#NotFound(
          \ 'Promise has not resolved/rejected and stores no value')
    endif
  endif
  return l:self.__value
endfunction
