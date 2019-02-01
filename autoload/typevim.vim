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
