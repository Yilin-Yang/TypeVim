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
"   buffer will be given a name that is arbitrary, but unique. If the given
"   name matches that of an existing (different) buffer, this function will
"   throw an ERROR(BadValue).
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
    \ 'destroy': function('typevim#Buffer#destroy'),
    \ 'getbufvar': function('typevim#Buffer#getbufvar'),
    \ 'setbufvar': function('typevim#Buffer#setbufvar'),
    \ 'bufnr': function('typevim#Buffer#bufnr'),
    \ 'Open': function('typevim#Buffer#Open'),
    \ 'Switch': function('typevim#Buffer#Switch'),
    \ 'SetBuffer': function('typevim#Buffer#SetBuffer'),
    \ 'split': function('typevim#Buffer#OpenSplit', [v:false]),
    \ 'vsplit': function('typevim#Buffer#OpenSplit', [v:true]),
    \ 'GetLines': function('typevim#Buffer#GetLines'),
    \ 'ReplaceLines': function('typevim#Buffer#ReplaceLines'),
    \ 'InsertLines': function('typevim#Buffer#InsertLines'),
    \ 'DeleteLines': function('typevim#Buffer#DeleteLines'),
    \ 'IsOpenInTab': function('typevim#Buffer#IsOpenInTab'),
  \ }

  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
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
  let a:default = get(a:000, 0, v:false)
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
function! typevim#Buffer#bufnr() dict abort
  call s:CheckType(l:self)
  return l:self['__bufnr']
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
  execute l:open_cmd.lself['__bufnr']
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
  let a:tabnr = typevim#ensure#IsNumber(get(a:000, 1, tabpagenr()))
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
  let a:force  = typevim#ensure#IsBool(get(a:000, 1, v:true))
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

" RETURN: (v:t_list)  A list containing the requested lines from this buffer.
" PARAM:  after (v:t_number)  Include lines starting *after* this line number.
" PARAM:  rnum  (v:t_number?) The last line to include in the range. If not
"                             specified, will be equal to lnum+1 (i.e. not
"                             specifying rnum will return a one-item list with
"                             the given line).
" PARAM:  strict_indexing   (v:t_bool?)   Throw error on 'line out-of-range.'
function! typevim#Buffer#GetLines(lnum, ...) dict abort
  call s:CheckType(l:self)
  let a:strict_indexing = get(a:000, 1, v:false)
  let a:rnum = get(a:000, 0, a:lnum)
  return nvim_buf_get_lines(l:self['__bufnr'], a:lnum, a:rnum, a:strict_indexing)
endfunction

" BRIEF:  Set, add to, or remove lines. Wraps `nvim_buf_set_lines`.
" PARAM:  after     (v:t_number)  Replace lines starting after this line number.
" PARAM:  through   (v:t_number)  Replace until this line number, inclusive.
" PARAM:  strict_indexing   (v:t_bool?)   Throw error on 'line out-of-range.'
" DETAILS:  See `:h nvim_buf_set_lines` for details on function parameters.
"           `{strict_indexing}` is always `v:false`.
function! typevim#Buffer#ReplaceLines(after, through, replacement, ...) dict abort
  call s:CheckType(l:self)
  let a:strict_indexing = get(a:000, 0, v:false)
  call nvim_buf_set_lines(
    \ l:self['__bufnr'],
    \ a:after,
    \ a:through,
    \ a:strict_indexing,
    \ a:replacement)
endfunction

" BRIEF:  Insert lines at a position.
" PARAM:  after   (v:t_number)  Insert text right after this line number.
" PARAM:  lines   (v:t_list)    List of `v:t_string`s: the text to insert.
" PARAM:  strict_indexing   (v:t_bool?)   Throw error on 'line out-of-range.'
function! typevim#Buffer#InsertLines(after, lines, ...) dict abort
  call s:CheckType(l:self)
  let a:strict_indexing = get(a:000, 0, v:false)
  call nvim_buf_set_lines(
    \ l:self['__bufnr'],
    \ a:after,
    \ a:after,
    \ a:strict_indexing,
    \ a:lines)
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
  let a:strict_indexing = typevim#ensure#IsBool(get(a:000, 0, v:false))
  call nvim_buf_set_lines(
    \ l:self['__bufnr'],
    \ a:after,
    \ a:through,
    \ a:strict_indexing,
    \ [])
endfunction

""
" @dict Buffer
" Whether this Buffer is open in the tabpage with the given [tabnr].
" @default tabnr=the current tabpage
" @throws BadValue if [tabnr] is less than 1.
" @throws WrongType if [tabnr] is not a number.
function! typevim#Buffer#IsOpenInTab(...) dict abort
  let a:tabnr = maktaba#ensure#IsNumber(get(a:000, 0, tabpagenr()))
  if a:tabnr <# 1
    throw maktaba#error#BadValue(
        \ 'Given tabnr should be 1 or greater: %d', a:tabnr)
  endif
  let l:this_buf = l:self.bufnr()
  let l:bufs_in_tab = tabpagebuflist(a:tabnr)
  for l:buf in l:bufs_in_tab
    if l:buf ==# l:this_buf | return v:true | endif
  endfor
  return v:false
endfunction
