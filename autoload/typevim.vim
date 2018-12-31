let s:Object = {
    \ 'TYPE': {'Object': 1},
    \ 'destroy': { -> 0},
    \ }

""
" Return a 'prototypical' instance of a class. Meant to be called from inside
" a type's constructor.
" {typename}  The name of the type being declared.
" {prototype} Dictionary object containing member variables (with default
"             values) and member functions, which might not be implemented.
" [Destructor]  Optional dictionary function that performs cleanup for the
"               object.
" @default Destructor = 0
function! typevim#Classify(typename, prototype, ...) abort
  let a:Destructor = get(a:000, 0, v:false)
  call maktaba#ensure#IsString(a:typename)
  call maktaba#ensure#IsDict(a:prototype)
  if !maktaba#value#IsFuncref(a:Destructor)
      \ && !maktaba#value#IsBool(a:Destructor)
    throw maktaba#error#WrongType('For a:Destructor in (typevim#Classify)')
  endif

  let l:new = deepcopy(s:Object)
  for [l:prop, l:Value] in a:prototype
    let l:new[l:prop] = l:Value
  endfor

  if maktaba#value#IsFuncref(a:Destructor)
    let l:new['destroy'] = a:Destructor
  endif

  return l:new
endfunction

""
" Return a 'prototypical' instance of a type that inherits from another. Meant
" to be called from inside a type's constructor.
" {typename}  The name of the derived type being declared.
" {Parent}    Funcref to the constructor of the base class. If arguments are
"             being passed, this should be a partial.
" {prototype} Dictionary object containing member variables (with default
"             values) and member functions, which might not be implemented.
" [Destructor]  Optional dictionary function that performs cleanup for the
"               object.
function! typevim#ClassifyDerived(typename, Parent, prototype, ...) abort
  let a:Destructor = get(a:000, 0, v:false)
  call maktaba#ensure#IsString(a:typename)
  call maktaba#ensure#IsFuncref(a:Parent)
  call maktaba#ensure#IsDict(a:prototype)
  if !maktaba#value#IsFuncref(a:Destructor)
      \ && !maktaba#value#IsBool(a:Destructor)
    throw maktaba#error#WrongType(
        \ 'For a:Destructor in (typevim#ClassifyDerived)')
  endif

  let l:new = a:Parent()
  if maktaba#value#IsFuncref(a:Destructor)
    if !has_key(l:new, 'DESTRUCTORS')
      let l:new['destroy'] = function('typevim#Destroy')
      let l:new['DESTRUCTORS'] = []
    endif
    let l:new['DESTRUCTORS'] += [a:Destructor]
  endif

  for [l:prop, l:Value] in a:prototype
    let l:new[l:prop] = l:Value
  endfor

  return l:new
endfunction

""
" @private
function! typevim#Destroy() abort dict
  let l:destructors = l:self['DESTRUCTORS']
  let l:i = len(l:destructors) - 1
  while l:i ># -1
    let l:Destructor = l:destructors[l:i]
    call function(l:Destructor, l:self)
    let l:i -= 1
  endwhile
endfunction
