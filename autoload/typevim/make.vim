""
" @section Class Definitions, make
" TypeVim offers helper functions for defining new object types. These are
" meant to be invoked from within an object's constructor.

""
" @section Declaring a Class, basic_decl
" @parentsection make
" In general, to declare a new class, one should:
"
" First, create a "namespaced" *.vim file for this class, i.e. a file in:
" >
"   myplugin/  # plugin root dir
"     autoload/
"       myplugin/  # autoload subdirectory; name matters
"         ExampleClass.vim
" <
" Unless you have a good reason not to, all of `ExampleClass`'s relevant
" functions should be declared in `ExampleClass.vim`. This has the benefit of
" placing all of `ExampleClass`'s function definitions in an appropriate
" "namespace": based on vim's naming rules for autoload scripts (see `:help
" autoload`), a function in `ExampleClass.vim` named `Foo()` will be invocable
" through `:call myplugin#ExampleClass#Foo()`."
"
" Second, declare a class constructor. By convention, a class constructor should be
" named `New`, e.g. `myplugin#ExampleClass#New()`. It may have any number of
" arguments.
"
" Third, inside the constructor, construct a class "prototype." This is a
" dictionary object initialized with your class's member variables and
" functions (sometimes called "class properties," like in JavaScript):
" >
"   " in myplugin/autoload/myplugin/ExampleClass.vim
"   function! myplugin#ExampleClass#New(num1, str2, ...) abort
"     " type checking (with vim-maktaba) not required, but strongly encouraged
"     call maktaba#ensure#IsNumber(a:num1)
"     call maktaba#ensure#IsString(a:str2)
"
"     " optional parameter with a default value of 3.14
"     let a:optional_float = maktaba#ensure#IsFloat(get(a:000, 0, 3.14))
"
"     let l:example_prototype = {
"         \ '_single_underscore': a:num1,
"         \ '_implies_var_is_private': a:str2,
"         \ '__double_underscore': a:optional_float,
"         \ '__means_definitely_private': 42,
"         \ 'PublicFunction': typevim#get#ClassFunc('PublicFunction'),
"         \ '__PrivateFunction': typevim#get#ClassFunc('__PrivateFunction'),
"         \ }
"
"     return typevim#make#Class(l:example_prototype)
"   endfunction
" <
"
" Fourth, implement the rest of the class. In the example given, we referred to a
" `PublicFunction()` and a `__PrivateFunction()`, so we implement both here:
" >
"   " still myplugin/autoload/myplugin/ExampleClass.vim
"   function! myplugin#ExampleClass#PublicFunction() dict abort
"     " NOTE: `dict` keyword is necessary to have access to l:self variable
"     echo 'Hello, World! My number is: ' . l:self['_single_underscore']
"   endfunction
"
"   function! myplugin#ExampleClass#__PrivateFunction() dict abort
"     " ...
"   endfunction
" <
" Note how the functions are named. In step (3), the calls to
" function(typevim#get#ClassFunc) return Funcrefs equivalent to
" `function('myplugin#ExampleClass#PublicFunction')` and
" `function('myplugin#ExampleClass#__PrivateFunction')`, respectively. (See
" `:help function()` and `:help Funcref` for more details on what this means.)
"
" You can see that the full `function('...')` expression is very verbose;
" `get#ClassFunc()` is a helper function to help eliminate that boilerplate.
"
" Finally, test your class, or just start using it!
" >
"   let ex_1 = myplugin#ExampleObject#new(1, 'foo')
"   let ex_2 = myplugin#ExampleObject#new(2, 'boo', 6.28)
"
"   call ex_1.PublicFunction()  " echoes 'Hello, World! My number is: 1'
"   call ex_2.PublicFunction()  " echoes 'Hello, World! My number is: 2'
" <

""
" @section Declaring a Derived Class (Polymorphism), poly_decl
" @parentsection make
"
" TODO

let s:RESERVED_ATTRIBUTES = typevim#attribute#ATTRIBUTES_AS_DICT()
let s:TYPE_ATTR = typevim#attribute#TYPE()
let s:DTOR_LIST_ATTR = typevim#attribute#DESTRUCTOR_LIST()

""
" Returns a string containing an error message complaining that the user tried
" to illegally assign to the "reserved attribute" {property}. Optionally
" prints the (stringified) value they tried to assign, [value].
"
" @throws InvalidArguments if more than one optional argument is given.
" @throws WrongType if either {property} or [value] are not strings.
function! s:IllegalRedefinition(attribute, ...) abort
  call maktaba#ensure#IsString(a:attribute)
  if a:0 ==# 1
    let a:value = a:1
    call maktaba#ensure#IsString(a:value)
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute "%s" with value: %s',
        \ a:attribute, a:value)
  elseif !a:0
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute: "%s"', a:attribute)
  else
    throw maktaba#error#InvalidArguments(
        \ 'Gave wrong number of optional arguments (should be 0 or 1): %d', a:0)
  endif
endfunction

""
" Assigns the given {Value} into the {attribute} of the given {dict},
" throwing an "IllegalRedefinition" exception if the given {attribute} has a
" preexisting value.
"
" @throws NotAuthorized if {attribute} is already defined on {dict}.
" @throws WrongType
function! s:AssignReserved(dict, attribute, Value) abort
  call maktaba#ensure#IsDict(a:dict)
  call maktaba#ensure#IsString(a:attribute)
  if has_key(a:dict, a:attribute)
    throw s:IllegalRedefinition(
        \ a:attribute, typevim#object#ShallowPrint(a:Value))
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
" @throws BadValue if the given {typename} is not a valid typename, see @function(typevim#value#IsValidTypename).
" @throws NotAuthorized if {prototype} defines attributes that should've been initialized by this function.
" @throws WrongType if arguments don't have the types named above.
function! typevim#make#Class(typename, prototype, ...) abort
  let a:Destructor = get(a:000, 0, 0)
  call typevim#ensure#IsValidTypename(a:typename)
  call maktaba#ensure#IsDict(a:prototype)

  let l:new = a:prototype  " technically l:new is just an alias
  call s:AssignReserved(l:new, s:TYPE_ATTR, [a:typename])

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
" Return a "prototypical" instance of a type that inherits from another. Meant
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
" @default clobber_base_vars=0
"
" @throws BadValue if {typename} is not a valid typename.
" @throws NotAuthorized when the given {prototype} would redeclare a non-Funcref member variable of the base class, and [clobber_base_vars] is not 1.
" @throws WrongType if arguments don't have the types named above.
function! typevim#make#Derived(typename, Parent, prototype, ...) abort
  let a:Destructor = get(a:000, 0, 0)
  let a:clobber_base_vars = maktaba#ensure#IsBool(get(a:000, 1, 0))
  call typevim#ensure#IsValidTypename(a:typename)

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
    if !has_key(l:base, s:DTOR_LIST_ATTR)
      let l:Old_dtor = l:base['Destroy']
      let l:base['Destroy'] = function('typevim#Destroy')
      let l:base[s:DTOR_LIST_ATTR] =
          \ maktaba#value#IsFuncref(l:Old_dtor) ? [l:Old_dtor] : []
    endif
    call add(l:base[s:DTOR_LIST_ATTR], a:Destructor)
  endif

  let l:new = l:base  " declare alias; we'll be assigning into the base
  let l:derived = typevim#make#Class(a:typename, a:prototype)

  call add(l:new[s:TYPE_ATTR], l:derived[s:TYPE_ATTR][0])

  for [l:key, l:Value] in items(l:derived)
    if has_key(s:RESERVED_ATTRIBUTES, l:key)
      continue
    endif
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
