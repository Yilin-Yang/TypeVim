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
" Second, declare a class constructor. By convention, a class constructor
" should be named `New`, e.g. `myplugin#ExampleClass#New()`. It may have any
" number of arguments.
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
"         \ 'PublicFunction':
"             \ typevim#PrefixFunc('PublicFunction'),
"         \ '__PrivateFunction':
"             \ typevim#PrefixFunc('__PrivateFunction'),
"         \ }
"
"     return typevim#make#Class(l:example_prototype)
"   endfunction
" <
"
" Fourth, implement the rest of the class. In the example given, we referred
" to a `PublicFunction()` and a `__PrivateFunction()`, so we implement both
" here:
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
" @function(typevim#PrefixFunc) return Funcrefs equivalent to
" `function('myplugin#ExampleClass#PublicFunction')` and
" `function('myplugin#ExampleClass#__PrivateFunction')`, respectively. See
" `:help function()` and `:help Funcref` for more details on what this means.
"
" You can see that the full `function('...')` expression is very verbose;
" `object#PrefixFunc()` is a helper function to help eliminate that
" boilerplate.
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
let s:CLN_UP_LIST_ATTR = typevim#attribute#CLEAN_UPPER_LIST()

let s:Default_dtor = { -> 0}

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
  let a:dict[a:attribute] = a:Value
endfunction

""
" Return a "typevim-configured" instance of a class. Meant to be called from
" inside a type's constructor, where it will take a {prototype} dictionary
" (containing member functions and member variables), annotate it with type
" information, and perform additional configuration (e.g. adding clean-uppers).
"
" {typename} is the name of the type being declared.
"
" {prototype} is a dictionary object containing member variables (with default
" values) and member functions, which might not be implemented.
"
" [CleanUp] is an optional dictionary function that performs cleanup for
" the object.
"
" @default CleanUp = 0
" @throws BadValue if the given {typename} is not a valid typename, see @function(typevim#value#IsValidTypename).
" @throws NotAuthorized if {prototype} defines attributes that should've been initialized by this function.
" @throws WrongType if arguments don't have the types named above.
function! typevim#make#Class(typename, prototype, ...) abort
  let a:CleanUp = get(a:000, 0, s:Default_dtor)
  call typevim#ensure#IsValidTypename(a:typename)
  call maktaba#ensure#IsDict(a:prototype)

  let l:new = a:prototype  " technically l:new is just an alias
  call s:AssignReserved(l:new, s:TYPE_ATTR, [a:typename])

  if maktaba#value#IsFuncref(a:CleanUp)
      \ || maktaba#value#IsNumber(a:CleanUp)
    call s:AssignReserved(l:new, 'CleanUp', a:CleanUp)
  else
    throw maktaba#error#WrongType(
        \ 'CleanUp should be a Funcref, or a number '
        \ . '(if not defining a clean-upper)')
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
" [CleanUp] is an optional dictionary function that performs cleanup for the
" object. When invoked, defined clean-uppers will be called in reverse order,
" i.e.  the "most derived" clean-upper will be called first, with the
" "original" base class clean-upper being called last.
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
  let a:CleanUp = get(a:000, 0, s:Default_dtor)
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

  if maktaba#value#IsFuncref(a:CleanUp)
    " only create clean-upper list if actually necessary
    if !has_key(l:base, s:CLN_UP_LIST_ATTR)
      let l:OldCleanUp = l:base['CleanUp']
      if l:OldCleanUp !=# s:Default_dtor
        let l:base[s:CLN_UP_LIST_ATTR] = [l:OldCleanUp, a:CleanUp]
      else
        let l:base['CleanUp'] = a:CleanUp
      endif
    endif
  endif

  let l:new = l:base  " declare alias; we'll be assigning into the base
  let l:derived = typevim#make#Class(a:typename, a:prototype)

  call add(l:new[s:TYPE_ATTR], a:typename)

  for [l:key, l:Value] in items(l:derived)
    if has_key(s:RESERVED_ATTRIBUTES, l:key)
      continue
    endif
    if has_key(l:base, l:key) && !maktaba#value#IsFuncref(l:base[l:key])
        \ && !a:clobber_base_vars
      throw maktaba#error#NotAuthorized('Inheritance would redefine a base '
          \ . 'class member variable: "%s" (Set [clobber_base_vars] if this '
          \ . 'is intentional.) Would overwrite with value: %s',
          \ l:key, typevim#object#ShallowPrint(l:Value))
    endif
    let l:new[l:key] = l:Value
  endfor

  return l:new
endfunction

""
" Return a Funcref to the function with the name constructed by concatenating
" the following: (1) the "autoload prefix" from which this function was
" called (e.g. if called from `~/.vim/bundle/myplugin/autoload/myplugin/foo.vim`
" the prefix would be "myplugin#foo#"); (2) the given {funcname}.
"
" This is meant as a convenience function to reduce boilerplate when declaring
" TypeVim objects. Instead of long, explicit assignments like,
" >
"   " ~/.vim/bundle/myplugin/autoload
"   function! myplugin#subdirectory#LongClassName##New() abort
"     " ...
"     let l:new = {
"       " ...
"       \ 'DoAThing': function('myplugin#subdirectory#LongClassName##DoAThing'),
"     " ...
"     return typevim#make#Class(l:new)
"   endfunction
"
"   function! myplugin#subdirectory#LongClassName##DoAThing() dict abort
"     " ...
" <
"
" One can instead write,
" >
"     " ...
"     let l:new = {
"       " ...
"       \ 'DoAThing': typevim#make#Member('DoAThing'),
"     " ...
" <
"
" Which is functionally equivalent.
function! typevim#make#Member(funcname) abort
  call maktaba#ensure#IsString(a:funcname)
  let l:full_name = typevim#value#GetStackFrame(1)

  " strip everything after the last '#'
  " (presumably, this is being called from a 'New' function or similar)
  let l:prefix = matchstr(l:full_name, '\zs.*\ze#.\{-}$')

  if empty(l:prefix)
    throw maktaba#error#BadValue(
        \ 'Not invoking this function from an autoload function '
        \ . '(called from: "%s")', l:full_name)
  endif

  return function(l:prefix.'#'.a:funcname)
endfunction
