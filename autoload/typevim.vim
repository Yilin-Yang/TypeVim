""
" @section Introduction, intro
" @stylized TypeVim
" @library
" @order intro summary functions dicts make
" A library providing a prototype-based class system in VimL.
"
" VimL allows users to assign Funcrefs into a dictionary; these |function|s,
" if declared with the |dict| attribute, will be able to access and modify
" their "owner" dictionary through a variable (`l:self`) accessible from
" within their function body. This allows for object-oriented programming
" (OOP).
"
" Unfortunately, VimL provides few of the "quality-of-life" features that make
" OOP powerful. It lacks type safety, for instance, and lacks explicit support
" for OOP features like polymorphism. Implementing these features in VimL is
" possible, but involves a great deal of boilerplate.
"
" TypeVim is meant to provide a sensible, standardized framework for "native"
" object-oriented programming in VimL.

""
" @section Summary, summary
" TypeVim is not a classical (no pun intended) "class-based" OOP system.
" TypeVim is built using VimL's |Dictionary-function|s, which allows for
" "piecemeal" construction of objects by assigning |Funcref|s, |Partial|s, and
" other variables into |Dictionaries|.

""
" @section Differences from Traditional OOP, differences
" @parentsection summary
" TypeVim is not a classical (no pun intended) "class-based" OOP system.
" TypeVim is built using VimL's |Dictionary-function|s, which allows for
" "piecemeal" construction of objects by assigning |Funcref|s, |Partial|s, and
" other variables into |Dictionaries|.
"
" @subsection "Native" VimScript Classes
" VimL does not provide for explicit class declarations, like C++ or Java; it
" is much more akin to the type system used in languages like JavaScript.
" To declare a "class," one must declare a function ("constructor") that
" creates a dict and assigns into it the class's member functions and
" variables: these dicts are called *prototypes*. The constructor returns
" copies of these prototypes as initialized "class instances."
"
" "Native" (i.e. non-TypeVim) VimL Class instances will lack type information
" (like the name of its class) unless assigned such information explicitly,
" and nothing prevents the programmer from altering its interface at runtime:
" by deleting member functions, altering them, redeclaring them, or adding new
" ones entirely.  This allows for JavaScript-esque monkey-patching at runtime,
" but can make it difficult to enforce type safety or preserve class invariants.
"
" @subsection Inheritance
" Inheritance, however, is concatenative; "derived classes" are just base class
" prototypes with new (or overwritten) member functions and variables. VimL
" (as far as I know) does not support behavior delegation, nor does it actually
" support JavaScript-esque `[[Prototype]]` chains. An object has, at
" construction, all of the class members that it will ever have, unless the
" user decides to explicitly alter that object's members at runtime.
"
" @subsection Clean-Uppers
" Prototype-based type systems, like JavaScript's, generally lack formal
" C++-style destructors; the same is true of VimL, and TypeVim by extension.
" Vim has its own |garbagecollect()|or that it uses for managing object
" lifetimes. This eliminates the need for explicit C++-style memory management
" on the programmer's end, but also prevents automatic, customizable
" RAII-style destruction when a variable "leaves scope."
"
" For this reason, TypeVim does not support user-declared destructors:
" instead, it offers "clean-uppers." Like destructors, clean-uppers perform
" "end-of-life" cleanup for an object (e.g. clearing |augroup|s and mappings),
" but unlike destructors: (1) they must be called explicitly; and (2) they do
" not actually destroy the object. Different clean-uppers can be declared at
" different points in a class hierarchy: when calling a class instance's
" `CleanUp()` function, those clean-uppers will be called in reverse order,
" going from the most derived class up to the base class.
"
" All valid TypeVim objects shall have a clean-upper, even if it does nothing.
" This is largely handled by TypeVim itself: calls to
" @function(typevim#make#Class) and @function(typevim#make#Derived) will
" automatically provide dummy clean-uppers if none are provided.

""
" @section Type Information, type
" @parentsection summary
" TypeVim objects are |dictionaries| annotated with a TYPE attribute. As of
" the time of writing, this is a |list| containing all of the object's
" typenames, ordered from the base class (at index zero) to the most derived
" class (at the end of the list). This list should not be modified directly.
"
" Declaring a class in TypeVim is done using helper functions:
" @function(typevim#make#Class) for base classes, and
" @function(typevim#make#Derived) for derived classes. The class's typename
" is a |string| that gets passed to these functions in the class's
" constructor. See @section(make) for more details.
"
" Users can check whether a TypeVim object is an instance of a particular type
" using @function(typevim#value#IsType), or assert the same using
" @function(typevim#ensure#IsType). Checking whether a given value is a
" TypeVim object at all is done using @function(typevim#value#IsValidObject),
" or the analogous function from the `ensure` namespace.

""
" @section Sugar, sugar
" @parentsection summary
" TypeVim also provides additional "sugar" meant to make OOP easier. As of the
" time of writing, this includes: pretty printers (like
" @function(typevim#object#PrettyPrint) and @function(typevim#object#ShallowPrint))
" for printing objects in human-readable fashion; the object-oriented
" @dict(Buffer) wrapper object, including its version-agnostic functions for
" editing the wrapped buffer "in the background"; and the @dict(Promise)
" datatype.

""
" @section About
" TypeVim is provided under the terms of the MIT license.

""
" Return a numerical constant representing "any type". As of the time of
" writing, this is the numerical value returned by `type(v:null)` (see
" |type()|), but this may change in the future.
function! typevim#Any() abort
  if typevim#value#HasTypeConstants()
    return type(v:null)
  endif
  return 7
endfunction

""
" Return the numerical value of |v:t_bool|.
function! typevim#Bool() abort
  if typevim#value#HasTypeConstants()
    return v:t_bool
  endif
  return 6
endfunction

""
" Return the numerical value of |v:t_dict|.
function! typevim#Dict() abort
  if typevim#value#HasTypeConstants()
    return v:t_dict
  endif
  return 4
endfunction

""
" Return the numerical value of |v:t_float|.
function! typevim#Float() abort
  if typevim#value#HasTypeConstants()
    return v:t_float
  endif
  return 5
endfunction

""
" Return the numerical value of |v:t_func|.
function! typevim#Func() abort
  if typevim#value#HasTypeConstants()
    return v:t_func
  endif
  return 2
endfunction

""
" Return the numerical value of |v:t_list|.
function! typevim#List() abort
  if typevim#value#HasTypeConstants()
    return v:t_list
  endif
  return 3
endfunction

""
" Return the numerical value of |v:t_number|.
function! typevim#Number() abort
  if typevim#value#HasTypeConstants()
    return v:t_number
  endif
  return 0
endfunction

""
" Return the numerical value of |v:t_string|.
function! typevim#String() abort
  if typevim#value#HasTypeConstants()
    return v:t_string
  endif
  return 1
endfunction
