""
" Iterate over each character in {Chars} from left-to-right, prepending a
" backslash before every occurrence of that character in {String}.
"
" If a character appears in {Chars} multiple times, it will be prefixed with
" that many backslashes.
" >
"   call typevim#string#EscapeChars('abc aa', 'a')  # returns '\abc \a\a'
"   call typevim#string#EscapeChars('abc aa', 'ab') # returns '\a\bc \a\a'
"   call typevim#string#EscapeChars('abc aa', 'aa') # returns '\\abc \\a\\a'
" <
" Each character will be read "one-at-a-time": if {Chars} is "\a", then all
" "\" characters will be escaped, followed by all "a" characters.
"
" @throws BadValue if {Chars} is an empty string.
" @throws WrongType if either {String} or {Chars} are not strings.
function! typevim#string#EscapeChars(String, Chars) abort
  let l:str = maktaba#ensure#IsString(a:String)
  call maktaba#ensure#IsString(a:Chars)
  if empty(a:Chars)
    throw maktaba#error#BadValue('Gave empty list of chars: %s', a:Chars)
  endif
  if empty(a:String) | return a:String | endif

  let l:i = 0 | while l:i <# len(a:Chars)
    let l:str = substitute(l:str, s:Disenchant(a:Chars[l:i]), '\\&', 'g')
  let l:i += 1 | endwhile

  return l:str
endfunction

""
" If the given *single* character has a special meaning in a |magic|
" regex pattern, return that character prefixed with a backslash. Otherwise,
" return the character.
function! s:Disenchant(char) abort
  if a:char ==# '~'
    " ~ is interpreted as a special character in match command
    return '\~'
  endif
  if match(s:MAGIC_CHARS, a:char) !=# -1
    return '\'.a:char
  endif
  return a:char
endfunction
let s:MAGIC_CHARS = '$.*~^\'
lockvar s:MAGIC_CHARS

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
