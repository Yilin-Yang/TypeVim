""
" @section Introduction, intro
" @stylized TypeVim
" @library
" @order intro summary logging functions dicts make
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
" @section Logging, logging
" The verbosity of TypeVim's error messages and exception text is
" configurable by changing |g:typevim_enable_verbose_error_messages| to `1`
" from its default value of `0`.
"
" Developers may benefit from setting higher levels of error message
" verbosity: this will, among other things, cause Promises rejected without an
" error handler to @function(typevim#object#PrettyPrint) themselves into the
" error message text, capturing a "self-snapshot" that may be useful for
" debugging. (Note that because vim's error messages don't render newline
" characters, in order for this output to be useful, one may have to
" copy-paste the error message into a buffer and "pre-process" it by replacing
" the `^@` literals with actual newlines.)
"
" Verbose error messages, however, may hurt performance, on top of being
" obnoxious and unsightly. For this reason, they are disabled by default.
"
" THIS SETTING SHALL NOT BE CHANGED INSIDE OF "PRODUCTION CODE."
" The intent is for verbose output to be enabled manually by plugin
" developers (on the command line, or in a test suite's .vimrc), or by end
" users who are trying to debug their configurations. A plugin silently
" changing this value would be very difficult to troubleshoot.

""
" @section About
" TypeVim is provided under the terms of the MIT license.

""
" Wrapper around @function(typevim#object#ShallowPrint), provided because it's
" shorter and easier to type.
function! typevim#PrintShallow(...) abort
  return call('typevim#object#ShallowPrint', a:000)
endfunction

""
" Wrapper around @function(typevim#object#PrettyPrint), provided because it's
" shorter and easier to type.
function! typevim#Print(...) abort
  return call('typevim#object#PrettyPrint', a:000)
endfunction

""
" Read in the given [v_exception] and |:throw| it. If [v_exception] starts
" with "Vim", prepend a space to avoid "E608: Cannot :throw exceptions with
" 'Vim' prefix" errors.
"
" Meant to be used when propagating a |v:exception| trapped by a "catch-all"
" |catch| statement.
"
" @default v_exception=|v:exception|
" @throws WrongType if [v_exception] is not a string.
function! typevim#Rethrow(...) abort
  let l:v_exception = maktaba#ensure#IsString(get(a:000, 0, v:exception))
  if match(l:v_exception, 'Vim') ==# 0
    throw ' '.l:v_exception
  else
    throw l:v_exception
  endif
endfunction

""
" Return a numerical constant representing "any type". As of the time of
" writing, this is the numerical value returned by `type(v:null)` (see
" |type()|), but this may change in the future.
function! typevim#Any() abort
  return s:ANY
endfunction
let s:ANY = typevim#value#HasTypeConstants() ? type(v:null) : 7

""
" Return the numerical value of |v:t_bool|.
function! typevim#Bool() abort
  return s:BOOL
endfunction
let s:BOOL = typevim#value#HasTypeConstants() ? v:t_bool : 6

""
" Return the numerical value of |v:t_dict|.
function! typevim#Dict() abort
  return s:DICT
endfunction
let s:DICT = typevim#value#HasTypeConstants() ? v:t_dict : 4

""
" Return the numerical value of |v:t_float|.
function! typevim#Float() abort
  return s:FLOAT
endfunction
let s:FLOAT = typevim#value#HasTypeConstants() ? v:t_float : 5

""
" Return the numerical value of |v:t_func|.
function! typevim#Func() abort
  return s:FUNC
endfunction
let s:FUNC = typevim#value#HasTypeConstants() ? v:t_func : 2

""
" Return the numerical value of |v:t_list|.
function! typevim#List() abort
  return s:LIST
endfunction
let s:LIST = typevim#value#HasTypeConstants() ? v:t_list : 3

""
" Return the numerical value of |v:t_number|.
function! typevim#Number() abort
  return s:NUMBER
endfunction
let s:NUMBER = typevim#value#HasTypeConstants() ? v:t_number : 0

""
" Return the numerical value of |v:t_string|.
function! typevim#String() abort
  return s:STRING
endfunction
let s:STRING = typevim#value#HasTypeConstants() ? v:t_string : 1

""
" @private
function! typevim#VerboseErrors() abort
  if !exists('g:typevim_enable_verbose_error_messages')
    let g:typevim_enable_verbose_error_messages = 0
  endif
  return g:typevim_enable_verbose_error_messages
endfunction
