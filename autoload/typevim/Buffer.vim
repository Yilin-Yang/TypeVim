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
  let a:properties = maktaba#ensure#IsDict(get(a:000, 0, {}))
  if empty(a:properties)
    let a:properties = deepcopy(s:default_props)
  else
    " fill in unspecified property from defaults
    for [l:key, l:val] in items(s:default_props)
      if has_key(a:properties, l:key)
        " check for correct argument types
        call maktaba#ensure#TypeMatches(a:properties[l:key], l:val)
      else
        let a:properties[l:key] = l:val
      endif
    endfor
  endif

  if empty(a:properties['bufname'])
    let s:bufname_mangle_ctr += 1
    let l:bufname = 'TypeVim::Buffer_'
    while bufnr('^'.l:bufname.s:bufname_mangle_ctr.'$') !=# -1
      " while we have name collisions, keep incrementing the counter
      let s:bufname_mangle_ctr += 1
    endwhile
    let l:bufname .= s:bufname_mangle_ctr
    let a:properties['bufname'] = l:bufname
  else
    let l:bufname = a:properties['bufname']
    let l:bufnr_match = bufnr(l:bufname)
    if l:bufnr_match !=# -1 && l:bufnr_match !=# a:properties['bufnr']
      throw maktaba#error#BadValue(
          \ 'Given bufname %s collides with buffer #%d',
          \ l:bufname, l:bufnr_match)
    endif
  endif

  let l:bufnr = a:properties['bufnr']
  let l:bufname = a:properties['bufname']
  if !l:bufnr
    let l:bufnr = bufnr('^'.l:bufname.'$', 1)
    " bufnr will *first* try to match the given bufname against existing
    " buffers; if it does not find a match, *then* it will create a buffer
    " with that name, but this buffer's name will include the ^ and $; but the
    " ^ and $ are necessary to force vim to consider only exact matches, of
    " which there should be none.
    "
    " do this, and then give the newly created buffer a correct name
    let l:winview = winsaveview()
    let l:old_redraw = &lazyredraw
    let l:cur_buf = bufnr('%')
    execute 'keepalt buffer '.l:bufnr
    execute 'file '.l:bufname
    execute 'keepalt buffer '.l:cur_buf
    let &lazyredraw = l:old_redraw
    call winrestview(l:winview)
  endif

  let l:new = {
    \ '__bufnr': l:bufnr,
    \ '_NormalizeLineNos': typevim#make#Member('_NormalizeLineNos'),
    \ 'getbufvar': typevim#make#Member('getbufvar'),
    \ 'setbufvar': typevim#make#Member('setbufvar'),
    \ 'bufnr': typevim#make#Member('bufnr'),
    \ 'Open': typevim#make#Member('Open'),
    \ 'Switch': typevim#make#Member('Switch'),
    \ 'SetBuffer': typevim#make#Member('SetBuffer'),
    \ 'split': typevim#make#Member('OpenSplit', [0]),
    \ 'vsplit': typevim#make#Member('OpenSplit', [1]),
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
      \ exists('s:props_to_set') ?
          \ s:props_to_set : ['bufhidden', 'buflisted', 'buftype', 'swapfile']
  for l:prop in s:props_to_set
    let l:val = a:properties[l:prop]
    call l:new.setbufvar('&'.l:prop, l:val)
  endfor

  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" @private
" @dict Buffer
" "Normalize" the given {startline} and {endline} into positive integers or
" `"$"`; leave positive line numbers untouched, but "wrap around" negative
" line numbers to the appropriate "true" line number. See
" @function(Buffer.ReplaceLines) for more details.
"
" Returns a list of the normalized values: `[startline_norm, endline_norm]`.
"
" @throws BadValue if the final normalized {startline} is greater than the normalized {endline}.
" @throws WrongType if {startline} or {endline} aren't a number or "$".
function! typevim#Buffer#_NormalizeLineNos(startline, endline) dict abort
  call s:CheckType(l:self)
  let l:num_lines = l:self.NumLines()
  return s:NormalizeLineNos(
      \ maktaba#ensure#TypeMatchesOneOf(a:startline, [0, '']),
      \ maktaba#ensure#TypeMatchesOneOf(a:endline,   [0, '']),
      \ l:num_lines)
endfunction

function! s:NormalizeLineNos(startline, endline, num_lines) abort
  let l:startline = s:NormalizeLineNo(a:startline, a:num_lines)
  let l:endline   = s:NormalizeLineNo(a:endline,   a:num_lines)
  if l:startline ># l:endline
    throw maktaba#error#BadValue(
        \ 'Given starting line no. %d is greater than ending line no. %d.',
        \ l:startline, l:endline)
  endif
  return [
      \ maktaba#ensure#IsNumber(l:startline),
      \ maktaba#ensure#IsNumber(l:endline)]
endfunction

function! s:NormalizeLineNo(line, num_lines) abort
  if maktaba#value#IsString(a:line)
    if a:line ==# '$'
      return a:num_lines + 1
    else
      call maktaba#ensure#IsNumber(a:num_lines)  " throw 'expected number'
    endif
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
  execute 'bwipeout! '.l:self['__bufnr']
endfunction

""
" @dict Buffer
" Invoke `getbufvar` on this Buffer's stored buffer with the given arguments.
" See `:h getbufvar` for argument details.
" @usage {varname} [default]
" @throws WrongType if {varname} is not a string.
function! typevim#Buffer#getbufvar(varname, ...) dict abort
  call s:CheckType(l:self)
  let a:default = get(a:000, 0, 0)
  let l:to_return = 0
  execute 'let l:to_return = getbufvar(l:self["__bufnr"], a:varname'
      \ . (type(a:default) !=# v:t_bool ? ', a:default)' : ')')
  return l:to_return
endfunction

""
" @dict Buffer
" Invoke `setbufvar` on this Buffer's stored buffer with the given arguments.
" See `:h setbufvar` for argument details.
" @throws WrongType if {varname} is not a string.
function! typevim#Buffer#setbufvar(varname, Val) dict abort
  call s:CheckType(l:self)
  call setbufvar(l:self['__bufnr'], a:varname, a:Val)
endfunction

""
" @dict Buffer
" Returns the |bufnr| of the buffer owned by this @dict(Buffer).
"
" @throws NotFound if this @dict(Buffer)'s buffer no longer exists.
function! typevim#Buffer#bufnr() dict abort
  call s:CheckType(l:self)
  let l:bufnr = l:self['__bufnr']
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
  let a:cmd = get(a:000, 0, '')
  let a:keepalt = get(a:000, 1, 0)
  let l:open_cmd = (a:keepalt ? 'keepalt ' : '') . 'buffer '
  if !empty(a:cmd) | let l:open_cmd .= a:cmd.' ' | endif
  execute l:open_cmd.l:self['__bufnr']
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
  let a:open_in_any = typevim#ensure#IsBool(get(a:000, 0, 1))
  let a:tabnr = maktaba#ensure#IsNumber(get(a:000, 1, tabpagenr()))
  let l:bufnr = l:self.bufnr()
  if a:tabnr ==# tabpagenr() || a:open_in_any
    " check if already open and active
    if winnr() ==# bufwinnr(l:bufnr) | return | endif
  endif
  let l:range = [a:tabnr]
  if a:open_in_any
    call extend(
        \ l:range,
        \ range(1, a:tabnr - 1) + range(a:tabnr + 1, tabpagenr('$')))
  endif
  for l:tab in l:range
    if !l:self.IsOpenInTab(l:tab) | continue | endif
    execute 'tabnext '.l:tab
    let l:winnr = bufwinnr(l:bufnr)
    execute l:winnr.'wincmd w'
    break
  endfor
  if bufnr('%') !=# l:bufnr || (!a:open_in_any && tabpagenr() !=# a:tabnr)
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
  let a:action = maktaba#ensure#IsString(get(a:000, 0, ''))
  let a:force  = typevim#ensure#IsBool(get(a:000, 1, 1))
  call maktaba#ensure#IsIn(a:action, ['', 'bunload', 'bdelete', 'bwipeout'])
  let l:to_return = l:self['__bufnr']
  if a:action !=# ''
    execute a:action . a:force ? '! ' : ' ' . l:to_return
  endif
  let l:self['__bufnr'] = a:bufnr
  return l:to_return
endfunction

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
  let a:orientation = a:open_vertical ? 'vertical ' : ' '
  let a:cmd  = maktaba#ensure#IsString(get(a:000, 0, ''))
  let a:pos  = maktaba#ensure#IsString(get(a:000, 1, ''))
  let a:size = maktaba#ensure#IsNumber(get(a:000, 2, 0))
  call maktaba#ensure#IsIn(
      \ a:pos, ['leftabove', 'aboveleft', 'rightbelow', 'belowright', 'topleft',
      \ 'botright'])
  execute 'silent '.a:pos.' '.a:orientation.' '.a:size.' split'
  execute 'buffer! '.l:self['__bufnr']
endfunction

""
" @dict Buffer
" Return the total number of lines in this buffer.
function! typevim#Buffer#NumLines() dict abort
  call s:CheckType(l:self)
  return len(getbufline(l:self.bufnr(), 1, '$'))
endfunction

""
" Return lines {startline} to [endline], end-inclusive, from this buffer as a
" list of strings. If [strict_indexing] is 1, throw exceptions when requesting
" a line from "out of range."
function! typevim#Buffer#GetLines(startline, ...) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsNumber(a:startline)
  let a:endline = maktaba#ensure#IsNumber(get(a:000, 0, a:startline))
  let a:strict_indexing = typevim#ensure#IsBool(get(a:000, 1, 0))
  return nvim_buf_get_lines(l:self['__bufnr'], a:startline, a:endline, a:strict_indexing)
endfunction

""
" Change, add, or remove lines from this buffer, replacing lines {startline}
" through {endline}, end-inclusive, with the given {replacement}, a list of
" strings (one string per line).
"
" {startline} and {endline} can assume special values, like 0, `"$"`, and
" negative numbers. 0 is the "line before-the-start" of the buffer; `"$"` is
" the "line after-the-end"; and negative numbers are used for "negative"
" indexing, where -1 is the last line of the buffer, -2 is the second-to-last
" line, and so on.
"
" If {startline} and {endline} are both 0, {replacement} will be prepended to
" the start of the buffer, above line 1. A {startline} value of `"$"` means
" that {replacement} should be appended to the end of the buffer, below the
" last line; if {endline} is not also `"$"`, in this case, ERROR(BadValue)
" will be thrown.
"
" A nonzero {startline} value and an {endline} value of `"$"` will replace
" all lines till the end of the buffer. If {startline} is nonzero and
" {endline} is 0, an ERROR(BadValue) will be thrown.
"
" If {startline} and {endline} are equal, then the function will insert
" {replacement} below line {startline}.
"
" @throws BadValue if the {startline} is positioned after the {endline} in the buffer, or if the given lines are out of range for the current buffer, or if {startline} is 0 or `"$"` and is unequal to {endline}.
" @throws WrongType if {startline} or {endline} are not numbers or "$", or if {replacement} is not a list of strings.
function! typevim#Buffer#ReplaceLines(startline, endline, replacement) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsList(a:replacement)
  let [l:lnum, l:end] = l:self._NormalizeLineNos(a:startline, a:endline)
  let l:num_lines = l:self.NumLines()
  if has('nvim')
    if l:lnum ==# l:num_lines  " append after the end
      let l:replace_after = -1
      if l:end !=# l:num_lines
        throw maktaba#error#BadValue(
            \ 'startline is past the end: %s; but endline is unequal: %s',
            \ l:lnum, l:end)
      endif
    elseif !l:lnum  " replace after before-the-start
      " echoerr l:end !=# '0'
      " echoerr string(l:lnum.', '.l:end)
      let l:replace_after = 0
    elseif l:lnum ># 0
      let l:replace_after = l:lnum - 1
      if !l:end
        throw maktaba#error#BadValue(
            \ 'endline was 0, but startline was not also 0',
            \ l:lnum, l:end)
      endif
    else
      throw maktaba#error#Failure('Expected normalized lnum, got: %d', l:lnum)
    endif

    if l:end ># 0
      " nvim_buf_set_lines is zero-based, end-exclusive,
      let l:replace_through = l:end  " so don't subtract
    elseif l:end ==# l:lnum
      let l:replace_through = l:replace_after
    else
      throw maktaba#error#Failure('Expected normalized end, got: %d', l:end)
    endif
    call nvim_buf_set_lines(
      \ l:self['__bufnr'],
      \ l:replace_after,
      \ l:replace_through,
      \ 0,
      \ a:replacement)
  elseif has('patch-8.1.0037')  " has appendbuflines (8.1.0037)
    " TODO
  elseif has('patch-8.0.1039')  " has setbuflines (0.1039);
    " TODO
  else
  endif
endfunction

""
" Insert the given {lines} just below line {after}.
" If {after} is `"$"`, append lines to the end of the buffer. If {after} is 0,
" prepend lines to the start of the buffer.
"
" @throws WrongType if {after} is not a number or `"$"`, or if {lines} is not
" a dict.
function! typevim#Buffer#InsertLines(after, lines) dict abort
  call s:CheckType(l:self)
  call l:self.ReplaceLines(a:after, a:after, a:lines)
  " call nvim_buf_set_lines(
  "   \ l:self['__bufnr'],
  "   \ a:after,
  "   \ a:after,
  "   \ a:strict_indexing,
  "   \ a:lines)
endfunction

""
" @dict Buffer
" Remove lines from this buffer over a range, starting after line number
" {after} and continuing until line number {through}. If [strict_indexing] is
" 1, an exception will be thrown if the given lines are "out of range".
"
" @throws WrongType if {after} or {through} are not numbers, or if [strict_indexing] is not a boolean.
function! typevim#Buffer#DeleteLines(after, through, ...) dict abort
  call s:CheckType(l:self)
  let a:strict_indexing = typevim#ensure#IsBool(get(a:000, 0, 0))
  call nvim_buf_set_lines(
    \ l:self['__bufnr'],
    \ a:after,
    \ a:through,
    \ a:strict_indexing,
    \ [])
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
  let a:tabnr = maktaba#ensure#IsNumber(get(a:000, 0, tabpagenr()))
  if a:tabnr <# 1
    throw maktaba#error#BadValue(
        \ 'Given tabnr should be 1 or greater: %d', a:tabnr)
  endif
  try
    let l:this_buf = l:self.bufnr()
  catch /ERROR(NotFound)/  " buffer no longer exists
    return 0
  endtry
  let l:bufs_in_tab = tabpagebuflist(a:tabnr)
  for l:buf in l:bufs_in_tab
    if l:buf ==# l:this_buf | return 1 | endif
  endfor
  return 0
endfunction
