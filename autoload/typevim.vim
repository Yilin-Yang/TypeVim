""
" @section Introduction, intro
" @stylized TypeVim
" @library
" @order intro functions make
" A library providing a crude, JavaScript-esque class system in vimscript.
"
" vimscript allows users to assign Funcrefs into a dictionary; these functions,
" if declared with the |[dict]| attribute, will be able to access and modify
" their "owner" dictionary through a variable (`l:self`) accessible from
" within their function body. This allows for object-oriented programming
" (OOP).
"
" Unfortunately, vimscript does not provide for safe and convenient OOP. It
" lacks inbuilt type checking (like what the TypeScript compiler might
" provide), for instance. It also lacks explicit support for OOP features like
" polymorphism.
"
" TypeVim is meant to provide a sensible, standardized framework for "native"
" object-oriented programming in vimscript.
