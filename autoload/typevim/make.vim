""
" @section Class Definitions, make
" TypeVim offers helper functions for defining new types. These are meant to
" be invoked from within an object's constructor.
"
" TODO expand

""
" Returns a string containing an error message complaining that the user tried
" to illegally assign to the "reserved attribute" {property}. Optionally
" prints the (stringified) value they tried to assign, [value].
"
" @throws InvalidArguments if more than one optional argument is given.
" @throws WrongType if either {property} or [value] are not strings.
function! s:IllegalRedefinition(property, ...) abort
  call maktaba#ensure#IsString(a:property)
  if a:0 ==# 1
    let a:value = a:1
    call maktaba#ensure#IsString(a:value)
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute "%s" with value: %s',
        \ a:property, a:value)
  elseif !a:0
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute: "%s"', a:property)
  else
    throw maktaba#error#InvalidArguments(
        \ 'Gave wrong number of optional arguments (should be 0 or 1): %d', a:0)
  endif
endfunction

""
" Assigns the given {Value} into the {property} attribute of the given {dict},
" throwing an "IllegalRedefinition" exception if the given {property} has a
" preexisting value.
"
" @throws NotAuthorized if {property} is already defined on {dict}.
" @throws WrongType
function! s:AssignReserved(dict, property, Value) abort
  call maktaba#ensure#IsDict(a:dict)
  call maktaba#ensure#IsString(a:property)
  if has_key(a:dict, a:property)
    throw s:IllegalRedefinition(
        \ a:property, typevim#object#ShallowPrint(a:Value))
  endif
endfunction

""
" Return a "typevim-configured" instance of a class. Meant to be called from
" inside a type's constructor, where it will take a {prototype} dictionary
" (containing member functions and member variables), annotate it with type
" information, and perform additional configuration (e.g. adding destructors).
"
" {typename} is the name of the type being declared.
"
" {prototype} is a dictionary object containing member variables (with default
" values) and member functions, which might not be implemented.
"
" [Destructor] is an optional dictionary function that performs cleanup for
" the object.
"
" @default Destructor = 0
" @throws NotAuthorized if {prototype} defines attributes that should've been
" initialized by this function.
" @throws WrongType
function! typevim#make#Class(typename, prototype, ...) abort
  let a:Destructor = get(a:000, 0, 0)
  call maktaba#ensure#IsString(a:typename)
  call maktaba#ensure#IsDict(a:prototype)

  let l:new = a:prototype  " technically l:new is just an alias
  call s:AssignReserved(l:new, '___TYPE___', a:typename)

  if maktaba#value#IsFuncref(a:Destructor)
      \ || maktaba#value#IsNumber(a:Destructor)
    call s:AssignReserved(l:new, 'Destroy', a:Destructor)
  else
    throw maktaba#error#WrongType(
        \ 'Destructor should be a Funcref, or a number '
        \ . '(if not defining a destructor)')
  endif

  return l:new
endfunction

""
" Return a 'prototypical' instance of a type that inherits from another. Meant
" to be called from inside a type's constructor.
"
" {typename} is the name of the derived type being declared.
"
" {Parent} is either a Funcref to the base class constructor, or a base class
" prototype. If arguments must be passed to said constructor, in the former
" case, this should be a Partial.
"
" {prototype} is a dictionary object containing member variables (with default
" values) and member functions, which might be virtual. If the parent
" class defines functions with the same name (i.e. same dictionary key), they
" will be overridden with those of the {prototype}.
"
" [Destructor] is an optional dictionary function that performs cleanup for the
" object. On destruction, defined destructors will be called in reverse order,
" i.e.  the "most derived" destructor will be called first, with the
" "original" base class destructor being called last.
"
" [clobber_base_vars] is a boolean flag that, if true, will allow member
" variables of the base class to be overwritten by member variables of the
" derived class being declared. This is discouraged, since direct access and
" modification of base class member variables is generally considered bad
" style.
"
" @throws NotAuthorized when the given {prototype} would redeclare a non-Funcref
" member variable of the base class, and [clobber_base_vars] is not 1.
" @throws WrongType
function! typevim#make#Derived(typename, Parent, prototype, ...) abort
  let a:Destructor = get(a:000, 0, 0)
  let a:clobber_base_vars = maktaba#ensure#IsBool(get(a:000, 1, 0))
  call maktaba#ensure#IsString(a:typename)

  if maktaba#value#IsFuncref(a:Parent)
    let l:base = a:Parent()
  elseif maktaba#value#IsDict(a:Parent)
    let l:base = a:Parent
  else
    throw maktaba#error#WrongType(
        \ 'Given Parent should be a Funcref to base class constructor, '
        \ . 'or a base class "prototype" dict: %s',
        \ typevim#object#ShallowPrint(a:Parent))
  endif

  if maktaba#value#IsFuncref(a:Destructor)
    if !has_key(l:base, '___DESTRUCTORS___')
      let l:old_dtor = l:base['Destroy']
      let l:base['Destroy'] = function('typevim#Destroy')
      let l:base['___DESTRUCTORS___'] = [l:old_dtor]
    endif
    call add(l:base['___DESTRUCTORS___'], a:Destructor)
  endif

  let l:new = l:base  " declare alias; we'll be assigning into the base
  let l:derived = typevim#make#Class(a:typename, a:prototype)

  for [l:key, l:Value] in items(l:derived)
    if has_key(l:base, l:key) && !maktaba#value#IsFuncref(l:base[l:key])
        \ && !a:clobber_base_vars
      throw maktaba#error#NotAuthorized('Inheritance would redefine a base '
          \ . 'class member variable: "%s" (Set [clobber_base_vars] if this '
          \ . 'is intentional.) Would overwrite with value: %s',
          \ typevim#object#ShallowPrint(l:Value))
    endif
    let l:new[l:key] = l:Value
  endfor

  return l:new
endfunction
