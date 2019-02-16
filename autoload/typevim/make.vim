""
" @section Class Definitions, make
" TypeVim offers helper functions for defining new object types. These are
" meant to be invoked from within an object's constructor.

""
" Returns the script number of this file. Taken from vim's docs.
function! s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfun

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
" "namespace". Based on vim's naming rules for autoload scripts (see `:help
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
"     let l:optional_float = maktaba#ensure#IsFloat(get(a:000, 0, 3.14))
"
"     let l:example_prototype = {
"         \ '_single_underscore': a:num1,
"         \ '_implies_var_is_private': a:str2,
"         \ '__double_underscore': l:optional_float,
"         \ '__means_definitely_private': 42,
"         \ 'PublicFunction':
"             \ typevim#make#Member('PublicFunction'),
"         \ '__PrivateFunction':
"             \ typevim#make#Member('__PrivateFunction'),
"         \ }
"
"     return typevim#make#Class('ExampleClass', l:example_prototype)
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
" @function(typevim#make#Member) return Funcrefs equivalent to
" `function('myplugin#ExampleClass#PublicFunction')` and
" `function('myplugin#ExampleClass#__PrivateFunction')`, respectively. See
" `:help function()` and `:help Funcref` for more details on what this means.
"
" You can see that the full `function('...')` expression is very verbose;
" `typevim#make#Member()` is a helper function to help eliminate that
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
" Declaring a derived class is extremely similar to declaring a class
" normally: the main difference is that, in a derived class's constructor, one
" only has to specify (in addition to the derived class's member variables and
" functions) the base class functions that it overrides.
"
" Say that we're declaring a `DerivedClass` that inherits from the
" `ExampleClass` declared in @section(basic_decl). We could write:
" >
"   " in myplugin/autoload/myplugin/DerivedClass.vim
"   function! myplugin#DerivedClass#New(mem_var) abort
"     call maktaba#ensure#IsString(a:mem_var)
"
"     let l:derived_prototype = {
"         \ '__mem_var': a:mem_var,
"         \ 'PublicFunction':
"             \ typevim#make#Member('OverridesPublicFunction'),
"         \ 'DerivedClassFunc':
"             \ typevim#make#Member('DerivedClassFunc'),
"         \ }
"
"     return typevim#make#Derived(
"         \ 'DerivedClass', myplugin#ExampleClass#New(), l:example_prototype)
"   endfunction
" <
"
" This will return an object having `__mem_var`, a member function called
" `DerivedClassFunc()`, and all of `ExampleObject`'s functions and member
" variables; `ExampleObject`'s `PublicFunction`, however, would be overridden
" with `function! myplugin#DerivedClass#OverridesPublicFunction()`.
"
" TypeVim class hierarchies can have arbitrary depth, but TypeVim does not
" support multiple inheritance: every type must have at most one immediate
" parent type.
"
" @subsection Pure Virtual Functions
" It is possible to define pure virtual functions in TypeVim classes. These
" functions are "skeletons" that let you define the virtual function's
" interface, but which must be overridden to actually be used.
"
" Say that we wanted `ExampleClass#PublicFunction` to be pure virtual. We
" could write:
" >
"   " in myplugin/autoload/myplugin/ExampleClass.vim
"   function! myplugin#ExampleClass#New(num1, str2, ...) abort
"     " ...
"     let l:example_prototype = {
"         " ...
"         \ 'PublicFunction':
"             \ typevim#make#AbstractFunc(
"                 \ 'ExampleClass', 'PublicFunction', []),
"         \ }
"
"     return typevim#make#Class(l:example_prototype)
"   endfunction
" <
"
" Like @function(typevim#make#Member), @function(typevim#make#AbstractFunc)
" returns a |Funcref|. However, it returns a Funcref to a special,
" script-local "skeletal function": on invocation, this function will either
" throw ERROR(InvalidArguments) (or the VimL equivalents) when called with the
" wrong number of arguments, or throw `ERROR(NotImplemented)` if called with
" appropriate arguments.
"
" The final `[]` in the call to `AbstractFunc` is an arguments list, which can
" contain named arguments, optional arguments and a variable-length argslist.
" See @function(typevim#make#AbstractFunc) for more details.
"
" @subsection Clobbering Base Class Member Variables
" Note that you cannot override a base class's member variables in
" `DerivedClass` unless you set {clobber_base_vars} when calling
" @function(typevim#make#Derived). This to prevent bugs from accidentally
" declaring a member variable in the derived class that was already declared
" and used in the base class.

let s:RESERVED_ATTRIBUTES = typevim#attribute#ATTRIBUTES_AS_DICT()
let s:TYPE_ATTR = typevim#attribute#TYPE()
let s:CLN_UP_LIST_ATTR = typevim#attribute#CLEAN_UPPER_LIST()
let s:CLN_UP_FUNC = typevim#attribute#CLEAN_UPPER()

let s:TYPEVIM_INTERFACE = 'TypeVimInterface'

function s:DefaultCleanUpper() abort
  return 0
endfunction
let s:Default_dtor = function('<SNR>'.s:SID().'_DefaultCleanUpper')

""
" Clean-upper for an interface. Unlock the interface to allow modification or
" reassignment.
function s:InterfaceCleanUpper() dict abort
  unlockvar! l:self
  return 0
endfunction
let s:Interface_dtor = function('<SNR>'.s:SID().'_InterfaceCleanUpper')

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
    let l:value = a:1
    call maktaba#ensure#IsString(l:value)
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute "%s" with value: %s',
        \ a:attribute, l:value)
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
" Checks the given {Arg}. If {Arg} is a |Funcref|, returns it unmodified. If
" it is the number 0, returns the default "dummy" clean-upper. Else, throw an
" ERROR(WrongType).
function! s:ReadCleanUpper(Arg) abort
  if maktaba#value#IsNumber(a:Arg) && !a:Arg
    return s:Default_dtor
  endif
  return maktaba#ensure#IsFuncref(a:Arg)
endfunction

""
" Return a "typevim-configured" instance of a class. Meant to be called from
" inside a type's constructor, where it will take a {prototype} dictionary
" (containing member functions and member variables), annotate it with type
" information, perform additional configuration (e.g. adding clean-uppers),
" and return it for convenience.
"
" {typename} is the name of the type being declared.
"
" {prototype} is a dictionary object containing member variables (with default
" values) and member functions, which might not be implemented.
"
" [CleanUp] is an optional dictionary function that performs cleanup for
" the object, or 0. If [CleanUp] is 0, then the function will substitute a
" "dummy" clean-upper.
"
" @default CleanUp = 0
" @throws BadValue if the given {typename} is not a valid typename, see @function(typevim#value#IsValidTypename).
" @throws MissingFeature if the current version of vim does not support |Partial|s.
" @throws NotAuthorized if {prototype} defines attributes that should've been initialized by this function.
" @throws WrongType if arguments don't have the types named above.
function! typevim#make#Class(typename, prototype, ...) abort
  call typevim#ensure#HasPartials()
  let l:CleanUp = s:ReadCleanUpper(get(a:000, 0, 0))
  call typevim#ensure#IsValidTypename(a:typename)
  call maktaba#ensure#IsDict(a:prototype)

  let l:new = a:prototype  " technically l:new is just an alias
  call s:AssignReserved(l:new, s:TYPE_ATTR, [a:typename])

  if maktaba#value#IsFuncref(l:CleanUp)
      \ || maktaba#value#IsNumber(l:CleanUp)
    call s:AssignReserved(l:new, s:CLN_UP_FUNC, l:CleanUp)
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
" will be overridden with those of the {prototype}. The {prototype} dictionary
" given is modified after being passed in, and is returned from this function
" for convenience.
"
" [CleanUp] is an optional dictionary function that performs cleanup for the
" object, or 0. When invoked, defined clean-uppers will be called in reverse
" order, i.e. the "most derived" clean-upper will be called first, with the
" "original" base class clean-upper being called last. If [CleanUp] is 0, this
" function will substitute a "dummy" clean-upper.
"
" [clobber_base_vars] is a boolean flag that, if true, will allow member
" variables of the base class to be overwritten by member variables of the
" derived class being declared. This is discouraged, since direct access and
" modification of base class member variables is generally considered bad
" style.
"
" @default CleanUp=0
" @default clobber_base_vars=0
"
" @throws BadValue if {typename} is not a valid typename.
" @throws MissingFeature if the current version of vim does not support |Partial|s.
" @throws NotAuthorized when the given {prototype} would redeclare a non-Funcref member variable of the base class, and [clobber_base_vars] is not 1.
" @throws WrongType if arguments don't have the types named above, or if the base class {Parent} is not a valid TypeVim object.
function! typevim#make#Derived(typename, Parent, prototype, ...) abort
  call typevim#ensure#HasPartials()
  call typevim#ensure#IsValidTypename(a:typename)
  let l:CleanUp = s:ReadCleanUpper(get(a:000, 0, 0))
  let l:clobber_base_vars = typevim#ensure#IsBool(get(a:000, 1, 0))

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
  call typevim#ensure#IsValidObject(l:base)

  if maktaba#value#IsFuncref(l:CleanUp)
    " only create clean-upper list if actually necessary
    if !has_key(l:base, s:CLN_UP_FUNC)
      " having no clean-upper would only occur if the base class isn't a
      " TypeVim object
      throw maktaba#error#Failure(
          \ 'Base class object is not a TypeVim object: %s',
          \ typevim#object#ShallowPrint(l:base))
    elseif !has_key(l:base, s:CLN_UP_LIST_ATTR)
      let l:OldCleanUp = l:base[s:CLN_UP_FUNC]
      if l:OldCleanUp !=# s:Default_dtor
        let l:base[s:CLN_UP_LIST_ATTR] = [l:OldCleanUp, l:CleanUp]
      else
        let l:base[s:CLN_UP_FUNC] = l:CleanUp
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
        \ && !l:clobber_base_vars
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
" Returns 1 when the given {Val} is a valid non-tag interface constraint, i.e.
" a |v:t_TYPE| or another interface, but not a list thereof, and not a tag.
function! s:IsConstraint(Val) abort
  if typevim#value#IsTypeConstant(a:Val)
    return 1
  endif
  try
    if typevim#value#IsType(a:Val, 'TypeVimInterface')
      return 1
    endif
  catch /ERROR(BadValue)/
    " ...
  endtry
  return 0
endfunction

function! s:ThrowWrongConstraintType(Gave) abort
  throw maktaba#error#WrongType(
      \ 'Values in interface prototype should be v:t_TYPE values, '
      \ . 'or lists thereof, or lists of allowable strings. Gave: %s',
      \ typevim#object#ShallowPrint(a:Gave))
endfunction

""
" Parse the given {prototype} into an immutable TypeVim interface object that
" can be used in calls to @function(typevim#value#Implements) and similar
" functions. The given {prototype} is modified directly, and is returned for
" convenience.
"
" The returned object is a TypeVim object with the typename
" `"TypeVimInterface"`. It is made immutable using |lockvar|. It may be
" unlocked through a call to its `CleanUp()` function.
"
" {typename} is the human-readable name of the interface.
"
" The structure of {prototype} is similar to that of TypeScript interfaces:
"
" Each key is the name of a property, and should be a valid identifier (see
" @function(typescript#value#IsValidIdentifier)), though each may end with a
" `"?"` to indicate that the property is optional.
"
" The value associated with that key is called a property constraint, and may
" be a:
" - Type constant, that is, a number indicating that property's type in
"   valid implementations of the interface, i.e. one of the values of
"   |v:t_TYPE| or the value returned by @function(typevim#Any()), or,
" - Another TypeVim interface object, or,
" - A valid TypeVim interface prototype, or,
" - A nonempty list of type constants values and/or TypeVim interface objects
"   and/or TypeVim interface prototypes, where each value corresponds to an
"   allowable type, or,
" - A nonempty list of strings ("tags"), where each string is an allowable
"   value for the property (inferred to be of type |v:t_string|).
"
" When writing an interface {prototype}, one may specify: a built-in |v:t_TYPE|
" constant (e.g. |v:t_dict|, |v:t_func|); the literal number value of a
" |v:t_TYPE| constant (e.g. `1` for |v:t_string|), though this is not
" recommended since it lacks readability; or use TypeVim's helper functions
" (e.g. @function(typevim#Number)), which return the same values as vim's
" built-in |v:t_TYPE|s. @function(typevim#Any()) may be used to indicate that
" any type is acceptable.
"
" The latter is version-agnostic and is recommended for compatibility reasons:
" the |v:t_TYPE| constants are not available in older versions of vim, where
" their use will throw |E121| "Undefined variable" exceptions. The presence of
" the |v:t_TYPE| constants can be checked using @function(typevim#value#HasTypeConstants).
"
" @throws BadValue if keys in {prototype} are not valid identifiers (the `"?"` character is valid at the end of these keys, however).
" @throws WrongType if {typename} is not a string, or {prototype} is not a dictionary, or if values in {prototype} are not |v:t_TYPE| values or a list of |v:t_TYPE| values or a list of strings
"
function! typevim#make#Interface(typename, prototype) abort
  call maktaba#ensure#IsString(a:typename)
  call maktaba#ensure#IsDict(a:prototype)

  " modify the prototype as follows:
  " - strip any question marks from key names
  " - replace each value with a dictionary of constraints:
  "   - is_optional: whether the property is optional
  "   - is_tag: whether the property is a string with few allowable values
  "   - type: the type of the property, or a list of types that the property
  "   may have
  for [l:key, l:Val] in items(a:prototype)
    call typevim#ensure#IsValidInterfaceProp(l:key)
    let l:constraints = {}

    let l:constraints['is_tag'] = 0
    let l:constraints['is_optional'] = 0
    if l:key[-1:-1] ==# '?'
      let l:constraints['is_optional'] = 1
      unlet a:prototype[l:key]
      let l:key = l:key[:-2]  " trim question mark
      let a:prototype[l:key] = l:Val
    endif

    if maktaba#value#IsList(l:Val) && !empty(l:Val)
      let l:type_list = []
      if maktaba#value#IsString(l:Val[0])
        let l:constraints['is_tag'] = 1
        for l:tag in l:Val
          call add(l:type_list, maktaba#ensure#IsString(l:tag))
        endfor
      elseif s:IsConstraint(l:Val[0])
        for l:type in l:Val
          if !s:IsConstraint(l:type)
            call s:ThrowWrongConstraintType(l:type)
          endif
          call add(l:type_list, l:type)
        endfor
      else
        call s:ThrowWrongConstraintType(l:Val)
      endif
      let l:constraints['type'] = l:type_list
    elseif s:IsConstraint(l:Val)
      let l:constraints['type'] = l:Val
    elseif maktaba#value#IsDict(l:Val)
      let l:constraints['type'] = typevim#make#Interface('{interface}', l:Val)
    else
      call s:ThrowWrongConstraintType(l:Val)
    endif
    let a:prototype[l:key] = l:constraints
  endfor
  let a:prototype[typevim#attribute#INTERFACE()] = a:typename
  call typevim#make#Class(s:TYPEVIM_INTERFACE, a:prototype, s:Interface_dtor)
  lockvar! a:prototype
  return a:prototype
endfunction

""
" Throw an ERROR(BadValue) complaining of a mutually exclusive constraints.
function s:ThrowIncompatible(type, ...) abort
  call maktaba#ensure#IsString(a:type)
  if !has_key(s:incompats_to_errs, a:type)
    throw maktaba#error#Failure(
        \ 'Given incompatibility type %s not found in dict when printing error',
        \ a:type)
  endif
  try
    let l:error_msg = call('maktaba#error#NotAuthorized',
        \ [s:incompats_to_errs[a:type]] + a:000)
  catch
    throw maktaba#error#Failure(
        \ 'Failed to produce error msg. for incompatible interfaces, err: %s, '
          \ . 'args: %s, %s',
        \ v:exception, a:type, typevim#object#ShallowPrint(a:000))
  endtry
  throw l:error_msg
endfunction
let s:incompats_to_errs = {}
let s:incompats_to_errs['DIFFERENT_TYPE'] =
    \ 'Property "%s", with type constraint: %s, has different type in base: %s'
let s:incompats_to_errs['NONOPTIONAL_IN_BASE'] =
    \ 'Optional property "%s" is non-optional in base interface.'
let s:incompats_to_errs['TYPE_TOO_PERMISSIVE'] =
    \ 'Property "%s", with type constraint: %s, allows types not allowed in '
    \ . 'base, including: %s'

""
" Return an interface, with the name {typename}, based on {prototype} that
" extends the given {base} interface. As with @function(typevim#makeInterface),
" the given {prototype} is modified directly and locked using |lockvar|.
"
" Any object that implements the interface made from {prototype} must
" necessarily implement the {base} interface, i.e. {prototype} cannot impose
" constraints that are incompatible with the {base} interface, such that an
" object cannot implement both interfaces at the same time.
"
" @throws BadValue if keys in {prototype} are not valid identifiers (the `"?"` character is valid at the end of these keys, however).
" @throws NotAuthorized if a property constraint in {prototype} is incompatible with a property constraint in {base}.
" @throws WrongType if {typename} is not a string, {base} is not a TypeVim interface, or if {prototype} does not satisfy the type checks in @function(typevim#make#Interface).
function! typevim#make#Extension(typename, base, prototype) abort
  call maktaba#ensure#IsString(a:typename)
  call typevim#ensure#IsType(a:base, s:TYPEVIM_INTERFACE)
  call maktaba#ensure#IsDict(a:prototype)

  let l:extension = typevim#make#Interface(a:typename, a:prototype)
  unlockvar! l:extension

  let l:base = deepcopy(a:base)

  " verify that interfaces are compatible
  for [l:property, l:Constraints] in items(l:extension)
    if has_key(s:RESERVED_ATTRIBUTES, l:property) | continue | endif
    if !has_key(l:base, l:property) | continue | endif
    let l:BaseProp = l:base[l:property]

    if !l:BaseProp['is_optional'] && l:Constraints['is_optional']
      call s:ThrowIncompatible('NONOPTIONAL_IN_BASE', l:property)
    endif

    let l:base_type = maktaba#value#IsList(l:BaseProp['type']) ?
        \ l:BaseProp['type'] : [ l:BaseProp['type'] ]
    let l:this_type = maktaba#value#IsList(l:Constraints['type']) ?
        \ l:Constraints['type'] : [ l:Constraints['type'] ]
    if len(l:base_type) ==# 1 && len(l:this_type) ==# 1
      if l:base_type[0] !=# l:this_type[0]
        call s:ThrowIncompatible(
            \ 'DIFFERENT_TYPE', l:property, l:this_type[0], l:base_type[0])
      endif
    endif
    for l:type in l:this_type
      if index(l:base_type, l:type) ==# -1
        " this interface property allows a type not allowed in the base
        call s:ThrowIncompatible(
            \ 'TYPE_TOO_PERMISSIVE',
            \ l:property,
            \ typevim#object#ShallowPrint(l:this_type),
            \ l:type)
      endif
    endfor
  endfor

  " combine these interfaces, using the equivalent or more greatly constrained
  " properties from the extension when there's a name collision with the base
  call extend(l:extension, l:base, 'keep')
  lockvar! l:extension
  return l:extension
endfunction

""
" Return a |Funcref| to the function with the name constructed by concatenating
" the following: (1) the "autoload prefix" from which this function was
" called (e.g. if called from `~/.vim/bundle/myplugin/autoload/myplugin/foo.vim`
" the prefix would be "myplugin#foo#"); (2) the given {funcname}.
"
" If [arglist] or [dict] are provided, they are bound to the returned Funcref,
" turning it into a |Partial|. See |function()|.
"
" This is meant as a convenience function to reduce boilerplate when declaring
" TypeVim objects. Instead of long, explicit assignments like,
" >
"   " ~/.vim/bundle/myplugin/autoload
"   function! myplugin#subdirectory#LongClassName#New() abort
"     " ...
"     let l:new = {
"       " ...
"       \ 'DoAThing':
"           \ function('myplugin#subdirectory#LongClassName#DoAThing'),
"     " ...
"     return typevim#make#Class('LongClassName', l:new)
"   endfunction
"
"   function! myplugin#subdirectory#LongClassName#DoAThing() dict abort
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
"
" @default arglist=[]
" @default dict=nothing
" @throws MissingFeature if the current version of vim does not support |Partial|s.
" @throws WrongType if {funcname} is not a string, or [arglist] is not a list, or [dict] is not a dictionary.
function! typevim#make#Member(funcname, ...) abort
  call typevim#ensure#HasPartials()
  call maktaba#ensure#IsString(a:funcname)
  let l:arglist = maktaba#ensure#IsList(get(a:000, 0, []))
  if a:0 ># 1
    let l:dict = maktaba#ensure#IsDict(a:2)
  else
    let l:dict = 0
  endif
  let l:full_name = typevim#value#GetStackFrame(1)

  " strip everything after the last '#'
  " (presumably, this is being called from a 'New' function or similar)
  let l:prefix = matchstr(l:full_name, '\zs.*\ze#.\{-}$')

  if empty(l:prefix)
    throw maktaba#error#BadValue(
        \ 'Not invoking this function from an autoload function '
        \ . '(called from: "%s")', l:full_name)
  endif

  " function ignores empty arglists, but will bind to an empty dict
  if maktaba#value#IsDict(l:dict)
    return function(l:prefix.'#'.a:funcname, l:arglist, l:dict)
  else
    return function(l:prefix.'#'.a:funcname, l:arglist)
  endif
endfunction

""
" Returns a Partial, assignable into an object with type {typename}, standing
" in for a function named {funcname}, that takes in arguments with the names
" given in {parameters}.
"
" To specify optional parameters, enclose the parameter name in square
" brackets. To specify that a variable number of arguments are acceptable,
" write "...".
"
" Example invocation:
" >
"   let l:new['PureVirtualFunc'] = typevim#make#AbstractFunc(
"         \ 'ExampleObject`, 'exampleMethod', '['arg1', '[optional1]', '...'])
" <
"
" An argument list, if specified, must come after all other parameters named.
" Optional parameters, if specified, must come after all non-optional
" parameters, if any.
"
" Parameters names must be strings and cannot be empty strings, and must be
" valid identifiers (see @function(typevim#value#IsValidIdentifier)). They
" must also be unique.
"
" The returned function, when invoked, will throw: ERROR(InvalidArguments) if
" given the wrong number of arguments (and if Vim itself doesn't throw an
" "|E116|: Invalid arguments for function" exception or an "|E119|: Not enough
" arguments for function" exception); or an ERROR(NotImplemented), if the
" given arguments are valid.
"
" If the number of arguments is correct, the returned function will throw an
" exception saying that it is an unimplemented virtual function
" @throws BadValue if {parameters} does not adhere to the requirements above; or if {typename} s not a valid typename; or if {funcname} is not a valid identifier.
" @throws WrongType if {typename} isn't a string or {parameters} isn't a list of strings.
function! typevim#make#AbstractFunc(typename, funcname, parameters) abort
  call typevim#ensure#IsValidTypename(a:typename)
  call typevim#ensure#IsValidIdentifier(a:funcname)
  call maktaba#ensure#IsList(a:parameters)
  let l:named = []
  let l:opt_named = []
  let l:opt_arglist = []

  for l:param in a:parameters
    if !maktaba#value#IsString(l:param)
      throw maktaba#error#WrongType(
          \ 'Specified a non-string parameter "%s" in parameter list: %s',
          \ typevim#object#ShallowPrint(l:param),
          \ typevim#object#ShallowPrint(a:parameters))
    elseif empty(l:param) || l:param ==# '[]'
      throw maktaba#error#BadValue(
          \ 'Gave an empty string when naming a param in parameter list: %s',
          \ typevim#object#ShallowPrint(a:parameters))
    endif
    if !empty(l:opt_arglist)
        throw maktaba#error#BadValue(
            \ 'Specified a parameter "%s" after the optional argslist in '
            \ .'parameter list: %s',
            \ l:param, typevim#object#ShallowPrint(a:parameters))
    endif
    if l:param ==# '...'
      call add(l:opt_arglist, l:param)
      continue
    endif

    if l:param[0] ==# '[' && l:param[len(l:param) - 1] ==# ']'
      let l:param_id = l:param[1:-2]
      call typevim#ensure#IsValidIdentifier(l:param_id)
      call add(l:opt_named, l:param_id)
    else
      if !empty(l:opt_named)
        throw maktaba#error#BadValue(
            \ 'Specified a parameter "%s" after the optional parameter "%s" in '
              \ .'parameter list: %s',
            \ l:param, l:opt_named[-1],
            \ typevim#object#ShallowPrint(a:parameters))
      endif
      call typevim#ensure#IsValidIdentifier(l:param)
      call add(l:named, l:param)
    endif
  endfor

  let l:uniq_names = {}
  let l:all_named = l:named + l:opt_named
  for l:name in l:all_named
    if has_key(l:uniq_names, l:name)
      throw maktaba#error#BadValue(
          \ 'Specified a parameter name "%s" twice in parameter list: %s',
          \ l:name, typevim#object#ShallowPrint(a:parameters))
    endif
    let l:uniq_names[l:name] = 1
  endfor

  if empty(l:opt_named) && empty(l:opt_arglist)
    let l:ellipsis = []
  else
    let l:ellipsis = ['...']
  endif
  let l:param_list = join(l:named + l:ellipsis, ', ')
  let l:script_funcname = a:typename.'_'.a:funcname.'_NotImplemented'
  let l:argnum_cond =
      \ empty(l:opt_arglist) ? 'a:0 ># '.len(l:opt_named) : '1 ==# 0'
  let l:decl = 'function! s:'.l:script_funcname.'('.l:param_list.") abort\n"
      \ . '  if '.l:argnum_cond."\n"
      \ . '    throw maktaba#error#InvalidArguments("Too many optional '
      \ .              'arguments (Expected %d or fewer, got %d)", '
      \ .              len(l:opt_named).', a:0)'."\n"
      \ . '  endif'."\n"
      \ . '  throw maktaba#error#NotImplemented("Invoked pure virtual '
      \ .           'function: %s", "'.a:funcname.'")'."\n"
      \ . 'endfunction'
  " echoerr l:decl
  execute l:decl
  return function('<SNR>'.s:SID().'_'.l:script_funcname)
endfunction
