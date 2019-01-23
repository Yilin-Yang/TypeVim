""
" @section Class Definitions, make
" TypeVim offers helper functions for defining new types. These are meant to
" be invoked from within an object's constructor.
"
" TODO expand

let s:Object = {
    \ 'TYPE': {'Object': 1},
    \ 'destroy': { -> 0},
    \ }

""
" Return a 'prototypical' instance of a class. Meant to be called from inside
" a type's constructor.
"
" {typename} is the name of the type being declared.
"
" {prototype} Dictionary object containing member variables (with default values) and member functions, which might not be implemented.
"
" [Destructor]  Optional dictionary function that performs cleanup for the object.
" @default Destructor = 0
function! typevim#make#Class(typename, prototype, ...) abort
  let a:Destructor = get(a:000, 0, 0)
  call maktaba#ensure#IsString(a:typename)
  call maktaba#ensure#IsDict(a:prototype)
  if !(maktaba#value#IsFuncref(a:Destructor)
      \ || !maktaba#value#IsBool(a:Destructor))
    throw maktaba#error#WrongType(
        \ 'for a:Destructor, should be Funcref or the number 0')
  endif

  if has_key(a:prototype, 'TYPE') &&
      \ !(maktaba#value#IsDict(a:prototype['TYPE'])
          \ && empty(a:prototype['TYPE']))
    throw maktaba#error#BadValue("a:prototype has nonempty dict 'TYPE': %s")
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
"
" {typename} is he name of the derived type being declared.
"
" {Parent} is either a Funcref or a base class prototype. Funcref to the constructor of the base class. If arguments are
"             being passed, this should be a partial.
" {prototype} Dictionary object containing member variables (with default values) and member functions, which might not be implemented.
" [Destructor]  Optional dictionary function that performs cleanup for the object.
function! typevim#make#Derived(typename, Parent, prototype, ...) abort
  let a:Destructor = get(a:000, 0, 0)
  call maktaba#ensure#IsString(a:typename)
  let l:Base = maktaba#value#IsFuncref(a:Parent) ? a:Parent() : a:Parent
  call maktaba#ensure#IsDict(l:Base)
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
