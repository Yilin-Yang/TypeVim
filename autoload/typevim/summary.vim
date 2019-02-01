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
" for printing objects in human-readable fashion; and the @dict(Promise)
" datatype.
