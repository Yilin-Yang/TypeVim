""
" Split the given {string} on newlines (or on carriage-returns and newlines)
" into a list of separate lines, usable in a call to a function like
" |append()| or @function(Buffer.InsertLines). Useful for formatting the
" output of @function(typevim#object#PrettyPrint).
"
" [fileformat] controls the line endings on which this function will split.
" Acceptable values include:
"
" - "agnostic", which splits on an isolated <NL>, an isolated <CR>, the
"   substring <CR><NL>, or the substring <NL><CR>,
" - "unix", which splits only on <NL>,
" - "dos", which splits on either an isolated <NL> OR the substring <CR><NL>,
" - "mac", which splits only on <CR>,
"
" If this function does not split on a line ending character in {string} (e.g.
" if {string} contains a <CR>, but [fileformat] is "unix") then that character
" will be left unmodified in the returned list.
"
" If the string ends with a line ending character (e.g. {string} ends with an
" explicit <NL> and [fileformat] is "unix"), then the returned list will
" include an empty string at its end. If it ends with three such characters,
" then the returned list will include three empty strings, and so on.
"
" @default fileformat="agnostic"
" @throws WrongType if {string} is not a string.
function! typevim#string#Listify(string, ...) abort
  call maktaba#ensure#IsString(a:string)
  let l:fileformat = maktaba#ensure#IsIn(
      \ get(a:000, 0, 'agnostic'), s:listify_fileformats)

  let l:keepempty = 1
  if l:fileformat ==# 'agnostic'
    let l:split = split(
        \ a:string, '\(\r\n\)\|\(\n\r\)\|\(\r\)\|\(\n\)', l:keepempty)
  elseif l:fileformat ==# 'unix'
    let l:split = split(a:string, '\n', l:keepempty)
  elseif l:fileformat ==# 'dos'
    let l:split = split(a:string, '\(\r\n\)\|\(\n\)', l:keepempty)
  elseif l:fileformat ==# 'mac'
    let l:split = split(a:string, '\r', l:keepempty)
  endif

  return l:split
endfunction
let s:listify_fileformats = ['agnostic', 'unix', 'dos', 'mac']

""
" Prepend the given [indent_block] onto each line in {listified}, a list of
" strings usable in functions like |append()| and @function(Buffer.InsertLines).
" Returns the same list, for convenience.
"
" @default indent_block="  "
" @throws WrongType if {listified} is not a list of strings, or if [indent_block] is not a string.
function! typevim#string#IndentList(listified, ...) abort
  call maktaba#ensure#IsList(a:listified)
  let l:indent_block = maktaba#ensure#IsString(get(a:000, 0, '  '))
  if empty(l:indent_block) | return a:listified | endif

  let l:i = 0 | while l:i <# len(a:listified)
    let l:str = maktaba#ensure#IsString(a:listified[l:i])
    let a:listified[l:i] = l:indent_block.l:str
  let l:i += 1 | endwhile

  return a:listified
endfunction
