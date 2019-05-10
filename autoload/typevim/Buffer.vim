""
" @dict Buffer
" An encapsulation of a vim buffer; allows for manipulation of vim buffers as
" if they were objects.

" Used for creating unique 'filenames' for newly spawned buffers.
let s:bufname_mangle_ctr = 0

let s:typename = 'Buffer'
let s:default_props = {
    \ 'bufhidden': 'hide',
    \ 'buflisted': 0,
    \ 'bufname': '',
    \ 'bufnr': 0,
    \ 'buftype': 'nofile',
    \ 'modifiable': 1,
    \ 'swapfile': 0,
    \ }

""
" @dict Buffer
" @function typevim#Buffer#New([properties])
" Construct and return a new Buffer object. @dict(Buffer) objects can either
" create their own |buffers| on construction, or be "given" a buffer by
" specifying the `fname` of an existing buffer through the `fname` property of
" [properties].
"
" [properties] is a dictionary whose keys and values are used to configure the
" new buffer. These include:
"
" - `bufhidden`: A string. The buffer's |bufhidden| setting. Defaults to `hide`.
" - `buflisted`: A boolean. The buffer's |buflisted| setting. Defaults to 0.
" - `bufname`: A string. The name to be given to the buffer. If empty, the
"   buffer will be given a name that is arbitrary, but unique.
" - `bufnr`: A number. If empty or zero, then this @dict(Buffer) will be
"   initialized with a new vim buffer. This can be set to a nonzero value to
"   give this @dict(Buffer) ownership of an existing vim buffer with that
"   |bufnr|. Defaults to 0.
" - `buftype`: A string. The buffer's |buftype| setting. Defaults to `nofile`.
" - `modifiable`: A boolean. Whether or not the user can edit the buffer. When
"   true, the wrapped buffer is set to |nomodifiable|, but calls to functions
"   like @function(Buffer.InsertLines) will still be able to change the
"   buffer's contents.
" - `swapfile`: A boolean. The buffer's |swapfile| setting. Defaults to 0.
"
" All of these are optional and will have default values if not specified.
" Properties which are also vim settings can have any value that could be
" assigned to those settings explicitly, e.g. with `let &bufhidden = [...]`.
"
" If constructing a new buffer (i.e. `bufnr` is 0), then the given properties
" will be set on that buffer. If given an existing buffer (i.e. this
" @dict(Buffer) is being given the buffer with |bufnr| 3, so `bufnr` is 3),
" then this function will try to set those properties on that buffer (e.g.
" change the buffer's |bufname|, change the buffer's |swapfile|). The latter
" may fail and throw an exception.
"
" @default properties={}
" @throws BadValue if the given `bufname` matches an existing buffer that isn't `bufnr` (when nonzero), this function will throw an ERROR(BadValue).
" @throws WrongType if the type of a value in [properties] doesn't match the list above.
function! typevim#Buffer#New(...) abort
  let l:properties = maktaba#ensure#IsDict(get(a:000, 0, {}))
  if empty(l:properties)
    let l:properties = deepcopy(s:default_props)
  else
    " fill in unspecified property from defaults
    for [l:key, l:val] in items(s:default_props)
      if has_key(l:properties, l:key)
        " check for correct argument types
        call maktaba#ensure#TypeMatches(l:properties[l:key], l:val)
      else
        let l:properties[l:key] = l:val
      endif
    endfor
  endif

  if empty(l:properties.bufname)
    let s:bufname_mangle_ctr += 1
    let l:bufname = 'TypeVim::Buffer_'
    while bufnr('^'.l:bufname.s:bufname_mangle_ctr.'$') !=# -1
      " while we have name collisions, keep incrementing the counter
      let s:bufname_mangle_ctr += 1
    endwhile
    let l:bufname .= s:bufname_mangle_ctr
    let l:properties.bufname = l:bufname
  else
    let l:bufname = l:properties.bufname
    let l:bufnr_match = bufnr(l:bufname)
    if l:bufnr_match !=# -1 && l:bufnr_match !=# l:properties.bufnr
      throw maktaba#error#BadValue(
          \ 'Given bufname %s collides with buffer #%d, with bufname: %s',
          \ l:bufname, l:bufnr_match, bufname(l:bufnr_match))
    endif
  endif

  let l:bufnr = l:properties.bufnr
  let l:bufname = l:properties.bufname
  let l:need_rename = !l:bufnr
  if l:need_rename
    " bufnr will *first* try to match the given bufname against existing
    " buffers; if it does not find a match, *then* it will create a buffer
    " with that name, but this buffer's name will include the ^ and $; but the
    " ^ and $ are necessary to force vim to consider only exact matches, of
    " which there should be none.
    "
    " do this, and then give the newly created buffer a correct name down below
    let l:bufnr = bufnr('^'.l:bufname.'$', 1)
  endif

  let l:new = {
    \ '__bufnr': l:bufnr,
    \ 'ExchangeBufVars': typevim#make#Member('ExchangeBufVars'),
    \ 'OpenDoRestore': typevim#make#Member('OpenDoRestore'),
    \ 'SetDoRestore': typevim#make#Member('SetDoRestore'),
    \ 'getbufvar': typevim#make#Member('getbufvar'),
    \ 'setbufvar': typevim#make#Member('setbufvar'),
    \ 'bufnr': typevim#make#Member('bufnr'),
    \ 'Open': typevim#make#Member('Open'),
    \ 'Switch': typevim#make#Member('Switch'),
    \ 'SetBuffer': typevim#make#Member('SetBuffer'),
    \ 'search': typevim#make#Member('search'),
    \ 'split': typevim#make#Member('OpenSplit', [0]),
    \ 'vsplit': typevim#make#Member('OpenSplit', [1]),
    \ 'GetName': typevim#make#Member('GetName'),
    \ 'Rename': typevim#make#Member('Rename'),
    \ 'NumLines': typevim#make#Member('NumLines'),
    \ 'GetLines': typevim#make#Member('GetLines'),
    \ 'ReplaceLines': typevim#make#Member('ReplaceLines'),
    \ 'InsertLines': typevim#make#Member('InsertLines'),
    \ 'DeleteLines': typevim#make#Member('DeleteLines'),
    \ 'IsOpenInTab': typevim#make#Member('IsOpenInTab'),
  \ }

  call typevim#make#Class(s:typename, l:new, typevim#make#Member('CleanUp'))

  " set properties on the buffer
  let s:props_to_set =
      \ exists('s:props_to_set') ? s:props_to_set
                               \ : ['bufhidden', 'buflisted', 'buftype',
                                  \ 'modifiable', 'swapfile']
  for l:prop in s:props_to_set
    let l:val = l:properties[l:prop]
    call l:new.setbufvar('&'.l:prop, l:val)
  endfor

  if l:need_rename
    call l:new.Rename(l:bufname)
  endif

  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" @private
" Validate that the given line numbers comply with the indexing rules of
" @function(Buffer.ReplaceLines).
function! s:ValidateLineNumbers(startline, endline, num_lines) abort
  if !(a:startline && a:endline)
    throw maktaba#error#BadValue(
        \ 'Gave invalid line no. 0 in line range: [%d, %d]',
        \ a:startline, a:endline)
  elseif a:startline ># a:num_lines || a:endline ># a:num_lines
    throw maktaba#error#BadValue(
        \ 'Given line nos. are out of range (num_lines: %d): [%d, %d]',
        \ a:num_lines, a:startline, a:endline)
  endif
endfunction

""
" @private
" "Normalize" the given {line} and into a non-negative integer; leave positive
" line numbers untouched, but "wrap around" negative line numbers to the
" appropriate "true" line number using the number of lines in the buffer,
" {num_lines}. Returns the normalized line number.
"
" @throws WrongType if {line} is not a number or "$", or if {num_lines} is not a number.
function! s:NormalizeLineNo(line, num_lines) abort
  call maktaba#ensure#IsNumber(a:num_lines)
  if maktaba#value#IsString(a:line)
    if a:line ==# '$'
      return a:num_lines + 1
    else
      throw maktaba#error#WrongType(
          \ 'Given line number is a string, but is not "$": %s', a:line)
    endif
  else
    call maktaba#ensure#IsNumber(a:num_lines)
  endif
  if a:line >=# 0
    let l:to_return = a:line
  else  " negative indexing
    let l:to_return = a:num_lines + a:line + 1
  endif
  if l:to_return <# 0 || l:to_return ># a:num_lines + 1
    throw maktaba#error#BadValue('Line number out of range: %d', a:line)
  endif
  return l:to_return
endfunction

""
" @dict Buffer
" Perform cleanup for this Buffer object.
function! typevim#Buffer#CleanUp() dict abort
  call s:CheckType(l:self)
  execute 'bwipeout! '.l:self.__bufnr
endfunction

""
" @dict Buffer
" For each buffer variable/setting and value in {vars_and_vals}:
" - Replace the current value of "var" with "val",
" - Save the previous value of "var", and,
" - Return a dictionary of each modified variable, as well as its previous
"   value.
"
" The returned dictionary may be provided to this function to restore the
" original values of each variable or setting. Note that, if a "var" did not
" previously exit before the first call to this function, then the second call
" will simply set the value of that "var" to an empty string: it will not
" |unlet| it.
"
" @throws BadValue if a "var" is an empty string, the string "&", or if it is an option that does not exist. No modification of the buffer will take place.
" @throws WrongType if {vars_and_vals} is not a dict.
function! typevim#Buffer#ExchangeBufVars(vars_and_vals) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsDict(a:vars_and_vals)

  let l:prev_vals = {}
  let l:vars_and_vals = items(a:vars_and_vals)
  for [l:var, l:Val] in l:vars_and_vals
    if l:var ==# ''
      throw maktaba#error#BadValue(
          \ 'Gave a bufvar that was an empty string: %s',
          \ typevim#object#ShallowPrint(a:vars_and_vals))
    elseif l:var ==# '&'
      throw maktaba#error#BadValue(
          \ 'Cannot overwrite all buffer-local options at once! '
            \ . '(Gave "&" as a varname in: %s)',
          \ typevim#object#ShallowPrint(a:vars_and_vals))
    elseif l:var[0:0] ==# '&' && !exists(l:var)
      throw maktaba#error#BadValue('Option does not exist: %s', l:var)
    endif
    let l:prev_vals[l:var] = l:self.getbufvar(l:var)
  endfor
  for [l:var, l:Val] in l:vars_and_vals
    try
      call l:self.setbufvar(l:var, l:Val)
    catch
      throw maktaba#error#Failure(
          \ 'Setting bufvars failed on var: %s, with val: %s, and '
            \ . 'vars_and_vals dict: %s (threw: %s)',
          \ l:var, l:Val, typevim#object#ShallowPrint(a:vars_and_vals),
          \ v:exception)
    endtry
  endfor
  return l:prev_vals
endfunction

""
" @dict Buffer
" Silently perform the given {Action} with the buffer open and focused.
"
" Works just like @function(typevim#Buffer#SetDoRestore), but instead of
" setting variables, this function opens the managed buffer in a new tab,
" performs the {Action}, then closes that tab and returns to the previous
" view. This is done with |lazyredraw| enabled to avoid flickering, and the
" previous view and previous value of |lazyredraw| are restored even if
" executing {Action} results in an error.
"
" @throws WrongType if {Action} is not a Funcref or a string.
function! typevim#Buffer#OpenDoRestore(Action) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#TypeMatchesOneOf(a:Action, [function('s:CheckType'), ''])

  let l:old_tabpage = tabpagenr()
  let l:old_redraw = &lazyredraw

  try
    tabnew
    execute 'buffer '.l:self.__bufnr
    if maktaba#value#IsFuncref(a:Action)
      try
        let l:to_return = a:Action()
      catch /\(E116\)\|\(E118\)\|\(E119\)/
        " Invalid arguments | Too many arguments | Not enough arguments
        throw maktaba#error#BadValue(
            \ 'Funcref isn''it invocable with no arguments: %s',
            \ typevim#object#ShallowPrint(a:Action, 2))
            \ . ', resulted in: '.v:exception
      endtry
    else
      let l:to_return = 0
      execute a:Action
    endif
  finally
    tabclose
    execute 'tabnext '.l:old_tabpage
    let &lazyredraw = l:old_redraw
  endtry

  return l:to_return
endfunction

""
" @dict Buffer
" Set the given {temp_vars_and_vals} through a call to
" @function(Buffer.ExchangeBufVars), call {Action}, and then restore the old
" values from before setting {temp_vars_and_vals}, even if invoking {Action}
" results in an exception being thrown.
"
" {Action} should be a Funcref (or a |Partial|) that can be invoked without
" this function supplying arguments, or a string that can be passed to an
" |:execute| statement.
"
" If {Action} is a Funcref, returns its return value. Else, returns 0.
"
" @throws BadValue if {Action} is a Funcref, but needs arguments.
" @throws WrongType if {temp_vars_and_vals} is not a dict, or if {Action} is not a Funcref.
"
" This function throws the same exceptions as @function(Buffer.ExchangeBufVars).
function! typevim#Buffer#SetDoRestore(temp_vars_and_vals, Action) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsDict(a:temp_vars_and_vals)
  call maktaba#ensure#TypeMatchesOneOf(a:Action, [function('s:CheckType'), ''])
  let l:old_vals = l:self.ExchangeBufVars(a:temp_vars_and_vals)

  try
    if maktaba#value#IsFuncref(a:Action)
      try
        let l:to_return = a:Action()
      catch /\(E116\)\|\(E118\)\|\(E119\)/
        " Invalid arguments | Too many arguments | Not enough arguments
        throw maktaba#error#BadValue(
            \ 'Funcref isn''it invocable with no arguments: %s',
            \ typevim#object#ShallowPrint(a:Action, 2))
            \ . ', resulted in: '.v:exception
      endtry
    else  " is string
      let l:to_return = 0
      execute a:Action
    endif
  finally
    call l:self.ExchangeBufVars(l:old_vals)
  endtry

  return l:to_return
endfunction

""
" @dict Buffer
" Invoke `getbufvar` on this Buffer's stored buffer with the given arguments.
" See `:h getbufvar` for argument details.
" @usage {varname} [default]
" @throws WrongType if {varname} is not a string.
function! typevim#Buffer#getbufvar(varname, ...) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsString(a:varname)
  let l:default = get(a:000, 0, 0)
  let l:gave_default = a:0
  let l:to_return = 0
  execute 'let l:to_return = getbufvar(l:self["__bufnr"], a:varname'
      \ . (l:gave_default ? ', l:default)' : ')')
  return l:to_return
endfunction

""
" @dict Buffer
" Invoke `setbufvar` on this Buffer's stored buffer with the given arguments.
" See `:h setbufvar` for argument details.
" @throws WrongType if {varname} is not a string.
function! typevim#Buffer#setbufvar(varname, Val) dict abort
  call s:CheckType(l:self)
  call setbufvar(l:self.__bufnr, a:varname, a:Val)
endfunction

""
" @dict Buffer
" Returns the |bufnr| of the buffer owned by this @dict(Buffer).
"
" @throws NotFound if this @dict(Buffer)'s buffer no longer exists.
function! typevim#Buffer#bufnr() dict abort
  call s:CheckType(l:self)
  let l:bufnr = l:self.__bufnr
  if !bufexists(l:bufnr)
    throw maktaba#error#NotFound(
        \ "Buffer object's buffer %d no longer exists.", l:bufnr)
  endif
  return l:bufnr
endfunction

""
" @dict Buffer
" Open this buffer in the currently focused window.
"
" For details on [cmd], see `:h buffer`. [cmd] should include a leading `+`.
" If [keepalt] is 1, then the current alternate buffer will be preserved. See
" |keepalt|.
function! typevim#Buffer#Open(...) dict abort
  call s:CheckType(l:self)
  let l:cmd = get(a:000, 0, '')
  let l:keepalt = get(a:000, 1, 0)
  let l:open_cmd = (l:keepalt ? 'keepalt ' : '') . 'buffer '
  if !empty(l:cmd) | let l:open_cmd .= l:cmd.' ' | endif
  execute l:open_cmd.l:self.__bufnr
endfunction

""
" @dict Buffer
" Move the cursor to (one of) this buffer's window(s) in the given tab.
"
" If [open_in_any] is 1, then it is "acceptable" for this function to switch
" to a window in a different tabpage if that window has this buffer open.
"
" Prefers to switch to a buffer in the current tabpage, or the tabpage with
" the given [tabnr] if possible. Does nothing if the current tabpage is
" "acceptable" and the current window has this buffer open.
"
" @default open_in_any=0
" @default tabnr=the current tabpage
" @throws NotFound if this buffer isn't open in the tab(s) specified.
" @throws WrongType if [open_in_any] is not a boolean, or if [tabnr] is not a number.
function! typevim#Buffer#Switch(...) dict abort
  call s:CheckType(l:self)
  let l:open_in_any = typevim#ensure#IsBool(get(a:000, 0, 1))
  let l:tabnr = maktaba#ensure#IsNumber(get(a:000, 1, tabpagenr()))
  let l:bufnr = l:self.bufnr()
  if l:tabnr ==# tabpagenr() || l:open_in_any
    " check if already open and active
    if winnr() ==# bufwinnr(l:bufnr) | return | endif
  endif
  let l:range = [l:tabnr]
  if l:open_in_any
    call extend(
        \ l:range,
        \ range(1, l:tabnr - 1) + range(l:tabnr + 1, tabpagenr('$')))
  endif
  for l:tab in l:range
    if !l:self.IsOpenInTab(l:tab) | continue | endif
    execute 'tabnext '.l:tab
    let l:winnr = bufwinnr(l:bufnr)
    execute l:winnr.'wincmd w'
    break
  endfor
  if bufnr('%') !=# l:bufnr || (!l:open_in_any && tabpagenr() !=# l:tabnr)
    throw maktaba#error#NotFound(
        \ 'Could not find and switch to buffer %d!', l:bufnr)
  endif
endfunction

""
" @dict Buffer
" Replace the buffer owned by this Buffer object with {bufnr}.
"
" [action] controls what happens to the buffer being replaced. It can be an
" empty string, `"bunload"`, `"bdelete"`, or `"bwipeout"`: these will do
" nothing, |bunload|, |bdelete|, or |bwipeout| the replaced buffer,
" respectively.
"
" If [force] is 1, unsaved changes in the replaced buffer will be ignored when
" unloading, deleting, or wiping the buffer out.
"
" Returns the |bufnr| of the replaced buffer.
"
" @default action=""
" @default force=0
" @throws BadValue if [action] is not one of the values listed above.
" @throws NotFound if the given {bufnr} doesn't correspond to a real buffer.
" @throws WrongType if {bufnr} is not a number, if [action] is not a string, or if [force] is not a boolean.
function! typevim#Buffer#SetBuffer(bufnr, ...) dict abort
  call s:CheckType(l:self)
  if !bufexists(a:bufnr)
    throw maktaba#error#NotFound('Cannot find buffer #'.a:bufnr)
  endif
  let l:action = maktaba#ensure#IsString(get(a:000, 0, ''))
  let l:force  = typevim#ensure#IsBool(get(a:000, 1, 1))
  call maktaba#ensure#IsIn(l:action, ['', 'bunload', 'bdelete', 'bwipeout'])
  let l:to_return = l:self.__bufnr
  if l:action !=# ''
    execute l:action . l:force ? '! ' : ' ' . l:to_return
  endif
  let l:self.__bufnr = a:bufnr
  return l:to_return
endfunction

""
" @dict Buffer
" @usage {regexp} [flags] [startpos] [stopline] [timeout] [ignore_badflags]
" Perform a |search()| in the given buffer and return the result.
"
" Finds a line number matching the given {regexp} and returns it. A string of
" additional [flags] may be provided to modify the behavior of the search,
" which starts from the given [startpos].
"
" This function is a wrapper around the |search()| function. The wrapped
" buffer is silently (with |lazyredraw| enabled) opened in a new tabpage,
" where the search is performed. Prior to the search, the cursor position is
" set to the given [startpos]. After the search, the previous cursor position
" is restored, the new tab is closed, and |lazyredraw| is reset to its previous
" value. This will have side effects; for instance, any applicable buffer
" events (e.g. |BufEnter|) will fire.
"
" The following [flags] are supported. Matching is always done as if the 'n'
" flag is set, and other flags that affect movement of the cursor are ignored.
"   - 'b'   search Backward instead of forward
"   - 'c'   accept a match at the Cursor position
"   - 'p'   return number of matching sub-Pattern (see below)
"   - 'w'   Wrap around the end of the file
"   - 'W'   don't Wrap around the end of the file
"   - 'z'   start searching at the cursor column instead of Zero
"
" Providing flags not in the above list will cause an ERROR(BadValue) to be
" thrown, unless [ignore_badflags] is set to 1, in which case, the "bad" flags
" are silently ignored. The 'n' flag, if provided, is always ignored.
"
" [startpos] may be a number or a list. If it's a number, the search will
" start from the start of that line. If it's a list, it must use one of the
" following structures:
"   - [ lineno, colno ]
"   - [ ..., lineno, colno, ... ]
"   - [ ..., lineno, colno, ..., ... ]
"
" lineno must be a positive number. colno must be non-negative. The latter
" two are provided so that a list returned by |getpos()| or |getcurpos()| may
" be used as a [startpos] value.
"
" [stopline] and [timeout] are used like in |search()|, albeit with stricter
" input validation. While |search()| will perform type coercion if necessary
" and possible, this function will reject values that aren't numbers. A value
" of zero is like not giving the argument.
"
" @default flags=""
" @default startpos=1
" @default stopline=0
" @default timeout=0
" @default ignore_badflags=0
"
" @throws WrongType if {regexp} is not a string, [flags] is not a string, [startpos] is not a number or a list, or [ignore_badflags] is not a bool.
"
" @throws BadValue if [flags] contains unsupported flags and [ignore_badflags] is 0, or if [startpos] is a list without 2, 4, or 5 elements, or otherwise does not adhere to the requirements listed above, or if |setpos()| returns -1 when given (a "normalized") [startpos].
function! typevim#Buffer#search(regexp, ...) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsString(a:regexp)
  let l:flags = maktaba#ensure#IsString(get(a:000, 0, ''))
  let l:startpos = maktaba#ensure#TypeMatchesOneOf(get(a:000, 1, 1), [1, []])
  let l:stopline = maktaba#ensure#IsNumber(get(a:000, 2, 0))
  let l:timeout = maktaba#ensure#IsNumber(get(a:000, 3, 0))
  let l:ignore_badflags = typevim#ensure#IsBool(get(a:000, 4, 0))

  " set l:lineno and l:colno with appropriate values
  if maktaba#value#IsList(l:startpos)
    let l:normalized = []  " 'normalize' to [lineno, colno]
    let l:len = len(l:startpos)
    if l:len ==# 2
      let l:normalized = l:startpos
    elseif l:len ==# 4 || l:len ==# 5
      let l:normalized = l:startpos[1:2]
    else
      throw maktaba#error#BadValue(
          \ 'Gave an invalid startpos list (wrong length): '.
          \ typevim#object#ShallowPrint(l:startpos))
    endif
    let l:lineno = maktaba#ensure#IsNumber(l:normalized[0])
    let l:colno = maktaba#ensure#IsNumber(l:normalized[1])
  else  " is number
    let l:lineno = l:startpos
    let l:colno = 0
  endif
  if l:lineno <=# 0
    throw maktaba#error#BadValue(
        \ 'Gave bad line number: %d', l:lineno)
  endif
  if l:colno <# 0
    throw maktaba#error#BadValue(
        \ 'Gave bad column number: %d', l:colno)
  endif

  " check the given flags
  let l:flags_to_use = 'n'
  let l:i = 0 | while l:i <# len(l:flags)
    let l:f = l:flags[l:i]
    if match(s:valid_search_flags, l:f) ==# -1
      if !l:ignore_badflags
        throw maktaba#error#BadValue('Unsupported flag in search: %s', l:f)
      endif
    else
      let l:flags_to_use .= l:f
    endif
  let l:i += 1 | endwhile

  let l:old_tabpage = tabpagenr()
  let l:old_redraw = &lazyredraw
  let &lazyredraw = 1
    tabnew
    execute 'buffer '.l:self.__bufnr
    let l:old_curpos = getcurpos()
    if setpos('.', [0, l:lineno, l:colno, 0]) ==# -1
      " setpos failed, user gave bad startpos
      let &lazyredraw = l:old_redraw
      tabclose
      execute 'tabnext '.l:old_tabpage
      throw maktaba#error#BadValue(
          \ 'Given startpos not valid in buffer: %s', string(l:startpos))
    endif
    let l:to_return = search(a:regexp, l:flags_to_use, l:stopline, l:timeout)
    call setpos('.', l:old_curpos)
    tabclose
    execute 'tabnext '.l:old_tabpage
  let &lazyredraw = l:old_redraw

  return l:to_return
endfunction
let s:valid_search_flags = 'bcnpwWz'

""
" @dict Buffer
" Open this buffer in a split.
"
" If {open_vertical} is 1, opens in a vertical split; if {open_vertical} is 0,
" opens in a horizontal split.
"
" For [cmd], see `:h +cmd`. It may be empty string, and should include a
" leading `"+"` character.
"
" [pos] is the part of the screen in which the split should be created. See
" `:h topleft` and `:h botright`. It may be the empty string.
"
" [size] is the height/width of the horizontal/vertical split to be created.
" If 0, this parameter will be ignored.
"
" @default cmd=""
" @default pos=""
" @default size=0
"
" @throws BadValue if [pos] is not "leftabove", "aboveleft", "rightbelow", "belowright", "topleft", or "botright".
" @throws WrongType if {open_vertical} is not a boolean, if [cmd] is not a string, if [pos] is not a string, or if [size] is not a number.
function! typevim#Buffer#OpenSplit(open_vertical, ...) dict abort
  call s:CheckType(l:self)
  let l:orientation = a:open_vertical ? 'vertical ' : ' '
  let l:cmd  = maktaba#ensure#IsString(get(a:000, 0, ''))
  let l:pos  = maktaba#ensure#IsString(get(a:000, 1, ''))
  let l:size = maktaba#ensure#IsNumber(get(a:000, 2, 0))
  call maktaba#ensure#IsIn(
      \ l:pos, ['leftabove', 'aboveleft', 'rightbelow', 'belowright', 'topleft',
      \ 'botright'])
  execute 'silent '.l:pos.' '.l:orientation.' '.l:size.' split'
  execute 'buffer! '.l:self.__bufnr
endfunction

""
" @dict Buffer
" Get the |bufname| of the managed buffer. Equivalent to:
" >
"   call bufnr(buffer_dict.bufnr())
" <
function! typevim#Buffer#GetName() dict abort
  call s:CheckType(l:self)
  return bufname(l:self.bufnr())
endfunction

""
" @dict Buffer
" Change the name of this buffer to {new_name} through a call to |:file_f|.
"
" If {new_name} is an empty string, the name of the buffer will be cleared
" through a call to |:0file|.
"
" This will have side effects if this buffer does not have |buftype| `nofile`,
" since the buffer's name would actually be the name of the file to which the
" buffer would be saved on write.
"
" @throws WrongType if {new_name} is not a string.
function! typevim#Buffer#Rename(new_name) dict abort
  call s:CheckType(l:self)
  let l:is_clear = empty(maktaba#ensure#IsString(a:new_name))
  let l:command = (l:is_clear ? '0file' : 'file '.a:new_name) . ' | '
  call l:self.OpenDoRestore(l:command)
endfunction

""
" @dict Buffer
" Return the total number of lines in this buffer.
function! typevim#Buffer#NumLines() dict abort
  call s:CheckType(l:self)
  return len(getbufline(l:self.bufnr(), 1, '$'))
endfunction

""
" @dict Buffer
" Return lines {startline} to [endline], end-inclusive, from this buffer as a
" list of strings. Uses the same indexing rules as @function(Buffer.ReplaceLines).
"
" @default endline={startline}
function! typevim#Buffer#GetLines(startline, ...) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsNumber(a:startline)
  let l:endline = maktaba#ensure#IsNumber(get(a:000, 0, a:startline))
  let l:num_lines = l:self.NumLines()
  call s:ValidateLineNumbers(a:startline, l:endline, l:num_lines)
  let l:lnum = s:NormalizeLineNo(a:startline, l:num_lines)
  let l:end  = s:NormalizeLineNo(l:endline,   l:num_lines)
  if has('nvim')
    let l:after   = l:lnum - 1
    let l:through = l:end
    return nvim_buf_get_lines(l:self.__bufnr, l:after, l:through, 1)
  else  " getbufline is supported in pre-7.4
    return getbufline(l:self.__bufnr, l:lnum, l:end)
  endif
endfunction

function! s:ReplaceLines(startline, endline, replacement) dict abort
  call maktaba#ensure#IsNumber(a:startline)
  call maktaba#ensure#IsNumber(a:endline)
  call maktaba#ensure#IsList(a:replacement)

  let l:num_lines = l:self.NumLines()
  call s:ValidateLineNumbers(a:startline, a:endline, l:num_lines)
  let l:lnum = s:NormalizeLineNo(a:startline, l:num_lines)
  let l:end  = s:NormalizeLineNo(a:endline,   l:num_lines)
  if !(l:lnum ># 0 && l:end ># 0)
    throw maktaba#error#Failure(
        \ 'Expected normalized line range, got: [%d, %d]', l:lnum, l:end)
  elseif l:lnum ># l:num_lines || l:end ># l:num_lines
    throw maktaba#error#Failure(
        \ 'Normalized line nos. are out of range (num_lines: %d): [%d, %d]',
        \ l:num_lines, l:lnum, l:end)
  elseif l:lnum ># l:end
    throw maktaba#error#BadValue(
        \ 'Normalized {startline} is greater than {endline}. '
        \ . 'Gave: [%d, %d]; normalized to: [%d, %d]',
        \ a:startline, a:endline, l:lnum, l:end)
  endif

  if has('nvim')
    let l:replace_after   = l:lnum - 1
    let l:replace_through = l:end
    call nvim_buf_set_lines(
      \ l:self.bufnr(),
      \ l:replace_after,
      \ l:replace_through,
      \ 0,
      \ a:replacement)
  elseif typevim#value#HasDeleteBufline()
    let l:num_to_write = len(a:replacement)
    let l:num_in_range = l:end - l:lnum + 1
    let l:bufnr = l:self.bufnr()
    if l:num_to_write ==# l:num_in_range
      silent call setbufline(l:bufnr, l:lnum, a:replacement)
    else  " num lines to insert, num lines to be overwritten are different
      silent call deletebufline(l:bufnr, l:lnum, l:end)
      " note that deletebufline will 'scooch up' the lines below the given
      " range, so subtract one from the line number to append above them
      silent call appendbufline(l:bufnr, l:lnum - 1, a:replacement)
      if l:num_in_range ==# l:num_lines
        " remove superfluous last line, when replacing all lines in the buffer
        call deletebufline(l:bufnr, '$', '$')
      endif
    endif
  else  " fallback implementation
    " open the buffer and overwrite the given lines, then switch back
    let l:bufnr = l:self.bufnr()
    let l:cur_buf = bufnr('%')
    let l:winview = winsaveview()
    execute 'keepalt buffer '.l:bufnr
    silent call maktaba#buffer#Overwrite(l:lnum, l:end, a:replacement)
    execute 'keepalt buffer '.l:cur_buf
    call winrestview(l:winview)
  endif
endfunction

""
" @dict Buffer
" Change, add, or remove lines from this buffer, replacing lines {startline}
" through {endline}, end-inclusive, with the given {replacement}, a list of
" strings (one string per line).
"
" The number of lines in {replacement} can be does not need to be equal to
" `endline - startline + 1`, i.e. this function can replace part of a buffer
" with more lines than were originally there, or with fewer. For instance, if
" {replacement} is an empty list, the given line range will be deleted.
"
" Indexing is one-based: line 1 is the first line of the buffer. {startline}
" and {endline} can assume negative values; -1 is the last line of the buffer,
" -2 is the second-to-last line, and so on. 0 and `"$"` are not accepted
" values.
"
" This function still works even if the wrapped buffer is set as
" |nomodifiable|; it will set the buffer as |modifiable|, replace the given
" line range, and set the buffer back to |nomodifiable|.
"
" @throws BadValue if the {startline} is positioned after the {endline} in the buffer, or if the given lines are out of range for the current buffer, or if {startline} or {endline} are 0.
" @throws WrongType if {startline} or {endline} are not numbers, or if {replacement} is not a list of strings.
function! typevim#Buffer#ReplaceLines(startline, endline, replacement) dict abort
  call s:CheckType(l:self)
  call l:self.SetDoRestore(
      \ {'&modifiable': 1},
      \ function('s:ReplaceLines',
        \ [a:startline, a:endline, a:replacement], l:self))
endfunction

function! s:InsertLines(after, lines) dict abort
  let l:num_lines = l:self.NumLines()
  let l:lnum = s:NormalizeLineNo(a:after, l:num_lines)
  if has('nvim')
    if l:lnum ==# l:num_lines + 1
      let l:lnum = -1  " append to the end
    endif
    call nvim_buf_set_lines(
        \ l:self.bufnr(),
        \ l:lnum,
        \ l:lnum,
        \ 1,
        \ a:lines)
  elseif typevim#value#HasAppendBufline()
    " truncate line nos. 'past-the-end' to avoid out-of-range errors
    let l:lnum = l:lnum ># l:num_lines ? l:num_lines : l:lnum
    silent if appendbufline(
        \ l:self.bufnr(),
        \ l:lnum,
        \ a:lines)
      throw maktaba#error#Failure(
          \ 'Call to appendbufline() returned nonzero exit code')
    endif
  else  " fallback implementation
    " truncate line nos. 'past-the-end' to avoid out-of-range errors
    let l:lnum = l:lnum ># l:num_lines ? l:num_lines : l:lnum
    " open the buffer and append the lines, then switch back
    let l:bufnr = l:self.bufnr()
    let l:cur_buf = bufnr('%')
    let l:winview = winsaveview()
    execute 'keepalt buffer '.l:bufnr
    silent if append(l:lnum, a:lines)
      throw maktaba#error#Failure('Call to append() returned nonzero exit code')
    endif
    execute 'keepalt buffer '.l:cur_buf
    call winrestview(l:winview)
  endif
endfunction

""
" @dict Buffer
" Insert the given {lines} just below line {after}. Similar to
" @function(Buffer.ReplaceLines), except that it does not overwrite any of the
" lines in the buffer.
"
" This function uses the same indexing scheme @function(Buffer.ReplaceLines),
" with the following additions:
"
" - {after} may be 0, which is the "line before-the-start" of the buffer.
"   If {after} is 0, then the given {lines} will be prepended to the start of
"   the buffer, i.e. above line 1.
" - {after} may be `"$"`, which is the "line after-the-end" of the buffer. If
"   {after} is `"$"`, then the given {lines} will be appended to the end of
"   the buffer. (Note that you can also specify -1, or just explicitly specify
"   the line number of the last line in the buffer.)
"
" This function still works even if the wrapped buffer is set as
" |nomodifiable|; it will set the buffer as |modifiable|, insert the given
" {lines}, and set the buffer back to |nomodifiable|.
"
" @throws WrongType if {after} is not a number or `"$"`, or if {lines} is not a list.
function! typevim#Buffer#InsertLines(after, lines) dict abort
  call s:CheckType(l:self)
  call l:self.SetDoRestore(
      \ {'&modifiable': 1},
      \ function('s:InsertLines',
        \ [a:after, a:lines], l:self))
endfunction

""
" @dict Buffer
" Delete lines {startline} through {endline}, end-inclusive.
"
" This function still works even if the wrapped buffer is set as
" |nomodifiable|; it will set the buffer as |modifiable|, delete the given
" line range, and set the buffer back to |nomodifiable|.
"
" See @function(Buffer.ReplaceLines) for details on exceptions and indexing.
function! typevim#Buffer#DeleteLines(startline, endline) dict abort
  call s:CheckType(l:self)
  call l:self.ReplaceLines(a:startline, a:endline, [])
endfunction

""
" @dict Buffer
" Returns 1 if this @dict(Buffer) is open in the tabpage with the given
" [tabnr], and 0 otherwise. If the buffer owned by this @dict(Buffer) no
" longer exists, return 0.
"
" @default tabnr=the current tabpage
" @throws BadValue if [tabnr] is less than 1.
" @throws WrongType if [tabnr] is not a number.
function! typevim#Buffer#IsOpenInTab(...) dict abort
  let l:tabnr = maktaba#ensure#IsNumber(get(a:000, 0, tabpagenr()))
  if l:tabnr <# 1
    throw maktaba#error#BadValue(
        \ 'Given tabnr should be 1 or greater: %d', l:tabnr)
  endif
  try
    let l:this_buf = l:self.bufnr()
  catch /ERROR(NotFound)/  " buffer no longer exists
    return 0
  endtry
  let l:bufs_in_tab = tabpagebuflist(l:tabnr)
  for l:buf in l:bufs_in_tab
    if l:buf ==# l:this_buf | return 1 | endif
  endfor
  return 0
endfunction
