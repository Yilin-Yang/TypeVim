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
" Declaring a derived class is similar to declaring a class normally: the main
" difference is that, in a derived class's constructor, one only has to
" specify (in addition to the derived class's member variables and functions)
" the base class functions that it overrides.
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
let s:ATTRIBUTES_LIST = typevim#attribute#ATTRIBUTES()
let s:TYPE_ATTR = typevim#attribute#TYPE()
let s:TYPE_DICT_ATTR = typevim#attribute#TYPE_DICT()
let s:CLN_UP_LIST_ATTR = typevim#attribute#CLEAN_UPPER_LIST()
let s:CLN_UP_FUNC = typevim#attribute#CLEAN_UPPER()

let s:TYPEVIM_INTERFACE = 'TypeVimInterface'

""
" Function that takes any number of arguments and returns zero.
function! s:NoOp(...) abort
  return 0
endfunction
let s:No_op = function('s:NoOp')

""
" Execute CleanUppers in order from most- to least-derived.
function! s:CleanUpper() dict abort
  let l:dtor_list = l:self[typevim#attribute#CLEAN_UPPER_LIST()]
  let l:i = len(l:dtor_list) - 1 | while l:i >=# 0
    " bind to self, to avoid a 'calling dict function without dict' error
    let l:CleanUp = l:dtor_list[l:i]
    if maktaba#value#IsFuncref(l:CleanUp)
      let l:BoundCleanUp = typevim#object#Bind(l:CleanUp, l:self, [], 1)
      call l:BoundCleanUp()
    endif
  let l:i -= 1 | endwhile
  return 0
endfunction
let s:CleanUpAll = function('s:CleanUpper')

""
" Clean-upper for an interface. Unlock the interface to allow modification or
" reassignment.
function! s:InterfaceCleanUpper() dict abort
  unlockvar! l:self
  return 0
endfunction
let s:Interface_dtor = function('s:InterfaceCleanUpper')

""
" Returns a string containing an error message complaining that the user tried
" to illegally assign to the "reserved attribute" {property}. Optionally
" prints the (stringified) value they would have replaced, [existing], and the
" value they tried to assign, [value].
"
" @throws InvalidArguments if more than two optional arguments are given.
" @throws WrongType if either {property}, [existing], or [value] are not strings.
function! s:IllegalRedefinition(attribute, ...) abort
  call maktaba#ensure#IsString(a:attribute)
  if a:0 ==# 2
    let l:existing = maktaba#ensure#IsString(a:1)
    let l:value = maktaba#ensure#IsString(a:2)
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute "%s" (having preexisting '
          \ . 'value: %s) with value: %s',
        \ a:attribute, l:existing, l:value)
  elseif !a:0
    return maktaba#error#NotAuthorized(
        \ 'Tried to (re)define reserved attribute: "%s"', a:attribute)
  else
    throw maktaba#error#InvalidArguments(
        \ 'Gave wrong number of optional arguments (should be 0, 2): %d', a:0)
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
  call typevim#ensure#IsDict(a:dict)
  call maktaba#ensure#IsString(a:attribute)
  if has_key(a:dict, a:attribute)
    throw s:IllegalRedefinition(
        \ a:attribute, typevim#object#ShallowPrint(a:dict[a:attribute]),
        \ typevim#object#ShallowPrint(a:Value))
  endif
  let a:dict[a:attribute] = a:Value
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
  let l:CleanUp = maktaba#ensure#TypeMatchesOneOf(
      \ get(a:000, 0, 0), [0, function('typevim#make#Class')])
  " 'normalize' the numerical dummy value to zero
  if maktaba#value#IsNumber(l:CleanUp) | let l:CleanUp = 0 | endif
  call typevim#ensure#IsValidTypename(a:typename)
  call typevim#ensure#IsDict(a:prototype)

  let l:new = a:prototype  " technically l:new is just an alias
  call s:AssignReserved(l:new, s:TYPE_ATTR, [a:typename])
  call s:AssignReserved(l:new, s:CLN_UP_LIST_ATTR, [l:CleanUp])
  call s:AssignReserved(l:new, s:CLN_UP_FUNC, s:CleanUpAll)

  let l:typedict = {}
  let l:typedict[a:typename] = 1
  call s:AssignReserved(l:new, s:TYPE_DICT_ATTR, l:typedict)

  return l:new
endfunction

""
" Return a "prototypical" instance of a type that inherits from another. Meant
" to be called from inside a type's constructor.
"
" {typename} is the name of the derived type being declared.
"
" {Parent} is either a Funcref to the base class constructor, or a base class
" prototype. If arguments must be passed to the constructor in the former
" case, this should be a Partial. If {Parent} is a prototype, then it will not
" be modified: if it has dicts or lists as member variables, then the returned
" object's variables will be aliases to those same objects.
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
  let l:CleanUp = get(a:000, 0, 0)
  let l:clobber_base_vars = typevim#ensure#IsBool(get(a:000, 1, 0))

  if maktaba#value#IsFuncref(a:Parent)
    let l:base = a:Parent()
  elseif typevim#value#IsDict(a:Parent)
    " copy member variables, but deepcopy attributes (since the latter are
    " modified)
    " TODO rebind bound functions?
    let l:base = copy(a:Parent)
    for l:attr in s:ATTRIBUTES_LIST
      if has_key(a:Parent, l:attr)
        let l:base[l:attr] = deepcopy(a:Parent[l:attr])
      endif
    endfor
  else
    if typevim#VerboseErrors()
      throw maktaba#error#WrongType(
          \ 'Given Parent should be a Funcref to base class constructor, '
          \ . 'or a base class "prototype" dict: %s',
          \ typevim#object#ShallowPrint(a:Parent))
    else
      throw maktaba#error#WrongType(
          \ 'Given Parent should be a Funcref to base class constructor, '
          \ . 'or a base class "prototype" dict')
    endif
  endif
  call typevim#ensure#IsValidObject(l:base)

  let l:derived = typevim#make#Class(a:typename, a:prototype, l:CleanUp)

  let l:derived[s:CLN_UP_LIST_ATTR] =
      \ extend(l:base[s:CLN_UP_LIST_ATTR], l:derived[s:CLN_UP_LIST_ATTR])

  call add(l:base[s:TYPE_ATTR], a:typename)
  let l:base[s:TYPE_DICT_ATTR][a:typename] = 1
  let l:derived[s:TYPE_ATTR] = l:base[s:TYPE_ATTR]
  let l:derived[s:TYPE_DICT_ATTR] = l:base[s:TYPE_DICT_ATTR]

  for [l:key, l:Value] in items(l:base)
    if has_key(s:RESERVED_ATTRIBUTES, l:key)
      continue
    endif
    if has_key(l:derived, l:key)
      if !maktaba#value#IsFuncref(l:Value) && !l:clobber_base_vars
        if typevim#VerboseErrors()
          throw maktaba#error#NotAuthorized('Inheritance would redefine a base '
              \ . 'class member variable: "%s" (Set [clobber_base_vars] if '
              \ . 'this is intentional.) Would overwrite with value: %s',
              \ l:key, typevim#object#ShallowPrint(l:Value))
        else
          throw maktaba#error#NotAuthorized('Inheritance would redefine a base '
              \ . 'class member variable: "%s" (Set [clobber_base_vars] if '
              \ . 'this is intentional.)', l:key)
        endif
      else
        " if l:Value is a Funcref, preserve l:derived's Funcref, implementing
        " function overriding
      endif
    else
      " there's a base class member not in the derived class, so pop it in
      let l:derived[l:key] = l:Value
    endif
  endfor

  return l:derived
endfunction

function! s:ThrowWrongConstraintType(Gave) abort
  throw maktaba#error#WrongType(
      \ 'Values in interface prototype should be v:t_TYPE values, '
      \ . 'or lists thereof, or lists of allowable strings. Gave: %s',
      \ typevim#object#ShallowPrint(a:Gave))
endfunction

""
" Returns 1 when the given {Val} is a valid non-tag interface constraint,
" i.e.  a |v:t_TYPE| or another interface, but not a list thereof, and
" not a tag.
function! s:IsConstraint(Val) abort
  if typevim#value#IsTypeConstant(a:Val)
    return 1
  endif
  try
    if typevim#value#IsType(a:Val, 'TypeVimInterface') | return 1 | endif
  catch /ERROR(BadValue)/
    " ...
  endtry
  return 0
endfunction

function! s:MakeConstraintFromItem(Val) abort
  if typevim#value#IsList(a:Val)
    if typevim#VerboseErrors()
      throw maktaba#error#WrongType(
          \ 'Gave a list, but expected a single constraint: %s',
          \ typevim#object#ShallowPrint(a:Val))
    else
      throw maktaba#error#WrongType(
          \ 'Gave a list, but expected a single constraint!')
    endif
  elseif s:IsConstraint(a:Val)
    return a:Val
  elseif typevim#value#IsDict(a:Val)  " but not a 'concrete' interface yet,
    return typevim#make#Interface('INTERFACE_ANON', a:Val)
  else
    call s:ThrowWrongConstraintType(a:Val)
  endif
endfunction

function! s:MakeTypeList(constraint, type_list) abort
  call typevim#ensure#IsDict(a:constraint)
  let l:constraint_list = typevim#ensure#IsList(a:type_list)
  let l:to_return = []
  let l:i = 0 | while l:i <# len(l:constraint_list)
    let l:Item = l:constraint_list[l:i]
    call add(l:to_return, s:MakeConstraintFromItem(l:Item))
  let l:i += 1 | endwhile
  let a:constraint.type = l:to_return
  return a:constraint
endfunction

function! s:MakeTagList(constraint, tag_list) abort
  call typevim#ensure#IsDict(a:constraint)
  call typevim#ensure#IsList(a:tag_list)
  " just walk over the list, make sure it doesn't mix tag strings with
  " normal constraints
  let l:i = 0 | while l:i <# len(a:tag_list)
    let l:tag = a:tag_list[l:i]
    if !maktaba#value#IsString(l:tag)
      if typevim#VerboseErrors()
        throw maktaba#error#WrongType(
            \ 'Give a non-string value in a tag list: %s',
            \ typevim#object#ShallowPrint(l:tag))
      else
        throw maktaba#error#WrongType('Give a non-string value in a tag list!')
      endif
    endif
  let l:i += 1 | endwhile
  let a:constraint.type = a:tag_list
  let a:constraint.is_tag = 1
  return a:constraint
endfunction

""
" Given {Val}, return a 'refined' constraint (individual, or a list of) that
" that can be stored in a TypeVim interface object.
function! s:MakeConstraintFrom(constraint, Val) abort
  call typevim#ensure#IsDict(a:constraint)
  if typevim#value#IsList(a:Val)
    if empty(a:Val)
      throw maktaba#error#WrongType('Gave empty list in interface constraint')
    elseif maktaba#value#IsString(a:Val[0])
      return s:MakeTagList(a:constraint, a:Val)
    else
      return s:MakeTypeList(a:constraint, a:Val)
    endif
  else
    let a:constraint.type = s:MakeConstraintFromItem(a:Val)
    return a:constraint
  endif
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
" Each key is the name of a property, and should comply with the rules laid
" out by @function(typevim#value#IsValidInterfaceProp). These are essentially
" the same rules that define legal TypeScript interface properties, though
" arbitrary unicode characters are disallowed.
"
" The value associated with that key is called a property constraint, and may
" be a:
" - Type constant, that is, a number indicating that property's type in
"   valid implementations of the interface, i.e. one of the values of
"   |v:t_TYPE| or the value returned by @function(typevim#Any()), or,
" - Another TypeVim interface object, or,
" - A valid TypeVim interface prototype (which will have the {typename}
"   `"INTERFACE_ANON"`), or,
" - A nonempty list of type constants and/or TypeVim interface objects
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
  call typevim#ensure#IsDict(a:prototype)

  " modify the prototype as follows:
  " - strip any question marks from key names
  " - replace each value with a dictionary of constraints:
  "   - is_optional: whether the property is optional
  "   - is_tag: whether the property is a string with few allowable values
  "   - type: the type of the property, or a list of types that the property
  "   may have
  for [l:key, l:Val] in items(a:prototype)
    call typevim#ensure#IsValidInterfaceProp(l:key)
    " construct a 'constraint' representation, store it into the prototype
    let l:constraints = {}
    let l:constraints.is_tag = 0
    let l:constraints.is_optional = 0
    if l:key[-1:-1] ==# '?'
      let l:constraints.is_optional = 1
      unlet a:prototype[l:key]
      let l:key = l:key[:-2]  " trim question mark
      let a:prototype[l:key] = l:Val
    endif
    let l:constraints = s:MakeConstraintFrom(l:constraints, l:Val)
    let a:prototype[l:key] = l:constraints
  endfor
  let a:prototype[typevim#attribute#INTERFACE()] = a:typename
  call typevim#make#Class(s:TYPEVIM_INTERFACE, a:prototype, s:Interface_dtor)
  lockvar! a:prototype
  return a:prototype
endfunction

""
" Throw an ERROR(BadValue) complaining of a mutually exclusive constraints.
function! s:ThrowIncompatible(type, ...) abort
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
  call typevim#ensure#IsDict(a:prototype)

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

    let l:base_type = typevim#value#IsList(l:BaseProp['type']) ?
        \ l:BaseProp['type'] : [ l:BaseProp['type'] ]
    let l:this_type = typevim#value#IsList(l:Constraints['type']) ?
        \ l:Constraints['type'] : [ l:Constraints['type'] ]
    if len(l:base_type) ==# 1
      if l:base_type[0] ==# typevim#Any()
        " edge case: the base type is 'any', so any specialization is allowed
        continue
      elseif maktaba#value#IsString(l:this_type[0])
        " edge case: constraint is a tag, but the base's constraint is just
        " 'value has type string'. this is allowed, so skip further checks
        continue
      elseif len(l:this_type) ==# 1 && l:base_type[0] !=# l:this_type[0]
        " base and parent each have only one fixed type constraint, which
        " are incompatible
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
" Return a mutable object that is an implementation of the given {interface}.
" The returned object will be a "minimal" implementation, having no properties
" not originally found in {interface} (aside from standard TypeVim attributes,
" see @section(reserved)).
"
" The instance's typename will be the same as the typename of the interface.
"
" The value of each object property will be determined from its property
" constraint. If the property constraint is a single type constant:
" - |v:t_bool| defaults to (the number) 0.
" - |v:t_dict| defaults to `{}`, i.e. an empty dictionary.
" - |v:t_float| defaults to `0.0`.
" - |v:t_func| defaults to an arbitrary function that takes any number of
"   arguments and returns 0.
" - |v:t_list| defaults to `[]`, i.e. an empty list.
" - |v:t_number| defaults to 0.
" - |v:t_string| defaults to ''.
" - @function(typevim#Any) defaults to 0.
"
" If the property constraint is a tag list, the value defaults to the first
" tag in the list.
"
" If the property constraint is a TypeVim interface, the default value is a
" "default" implementation of that interface, as returned by, e.g. a recursive
" call to this function.
"
" If the property constraint is a list of type constants and/or TypeVim
" interfaces, the default value is populated from the first item in the list,
" e.g. the property:
" >
"   'someProperty': [v:t_float, v:t_number, g:some_interface]
" <
" will default to `0.0`, because |v:t_float| is the first item in the list.
"
" @throws BadValue if {interface} is not a dict.
" @throws WrongType if {interface} is not a TypeVim interface.
function! typevim#make#Instance(interface) abort
  call typevim#ensure#IsType(a:interface, 'TypeVimInterface')

  let l:interface_as_str = string(a:interface)
  if has_key(s:interface_to_instance, l:interface_as_str)
    return deepcopy(s:interface_to_instance[l:interface_as_str])
  endif

  let l:new = {}
  for [l:prop, l:Constraints] in items(a:interface)
    if has_key(s:RESERVED_ATTRIBUTES, l:prop) | continue | endif
    let l:new[l:prop] = s:DefaultValueOf(l:Constraints)
  endfor
  call typevim#make#Class(a:interface[typevim#attribute#INTERFACE()], l:new)
  let s:interface_to_instance[l:interface_as_str] = deepcopy(l:new)
  return l:new
endfunction
let s:interface_to_instance = {}

function! s:DefaultValueOf(Constraints) abort
  if !typevim#value#IsDict(a:Constraints)
    throw maktaba#error#Failure('Given property constraint is not a dict: %s',
        \ typevim#object#ShallowPrint(a:Constraints))
  endif
  let l:type = a:Constraints.type
  if a:Constraints.is_tag
    return a:Constraints.type[0]
  elseif typevim#value#IsList(l:type)
    " construct a sacrificial copy of these constraints, replacing the current
    " list of types with the very first value, then make a recursive call
    let l:con_copy = deepcopy(a:Constraints)
    let l:con_copy.type = l:type[0]
    return s:DefaultValueOf(l:con_copy)
  elseif typevim#value#IsDict(l:type)
      \ && typevim#value#IsType(l:type, 'TypeVimInterface')
    return typevim#make#Instance(l:type)
  elseif typevim#value#IsTypeConstant(l:type)
    " construct new dicts, lists, to avoid unexpected aliasing
    if     l:type ==# typevim#Dict() | return {}
    elseif l:type ==# typevim#List() | return []
    endif
    return s:TypeConstantsToDefaults[l:type]
  else
    throw maktaba#error#Failure('Could not produce a default value for '
          \ . 'interface property constraint: %s',
        \ typevim#object#ShallowPrint(l:type))
  endif
endfunction

let s:TypeConstantsToDefaults = {
    \ typevim#Any(): 0,
    \ typevim#Bool(): 0,
    \ typevim#Float(): 0.0,
    \ typevim#Func(): s:No_op,
    \ typevim#Number(): 0,
    \ typevim#String(): '',
    \ }

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
  let l:arglist = typevim#ensure#IsList(get(a:000, 0, []))
  if a:0 ># 1
    let l:dict = typevim#ensure#IsDict(a:2)
  else
    let l:dict = 0
  endif

  " memoize the last value returned from this function as a two-element list
  " first element: the value of expand('<sfile>'), or v:null
  " second element: return value
  let l:callstack = expand('<sfile>')
  if !exists('s:last_member_returned')
    let s:last_member_returned = [v:null, v:null]
  elseif s:last_member_returned[0] ==# l:callstack
    let l:prefix = s:last_member_returned[1]
  endif

  if !exists('l:prefix')
    let l:full_name = typevim#value#GetStackFrame(1)

    " strip everything after the last '#'
    " (presumably, this is being called from a 'New' function or similar)
    let l:prefix = matchstr(l:full_name, '\zs.*\ze#.\{-}$')

    if empty(l:prefix)
      throw maktaba#error#BadValue(
          \ 'Not invoking this function from an autoload function '
          \ . '(called from: "%s")', l:full_name)
    endif

    " memoize this value
    let s:last_member_returned = [l:callstack, l:prefix]
  endif

  " function ignores empty arglists, but will bind to an empty dict
  if typevim#value#IsDict(l:dict)
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
" @throws BadValue if {parameters} does not adhere to the requirements above; or if {typename} s not a valid typename.
" @throws WrongType if {typename} isn't a string or {parameters} isn't a list of strings.
function! typevim#make#AbstractFunc(typename, funcname, parameters) abort
  call typevim#ensure#IsValidTypename(a:typename)
  call maktaba#ensure#IsString(a:funcname)
  call typevim#ensure#IsList(a:parameters)
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
  return function('s:'.l:script_funcname)
endfunction
