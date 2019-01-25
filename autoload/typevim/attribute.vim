""
" @section Reserved Attributes, reserved
" @parentsection make
"
" Reserved attributes are properties of TypeVim objects that are "reserved" by
" TypeVim for "bookkeeping." These include the attributes used for tracking an
" object's dynamic type, its class hierarchy, its order of destructor calls,
" and so on.
"
" Users shall not modify these properties, as doing so will lead to undefined
" behavior. Attempting to explicitly set the values of these attributes (e.g.
" in a class constructor) will sometimes cause TypeVim to throw
" ERROR(NotAuthorized) exceptions.
"
" In general, the names of these attributes are fully capitalized and enclosed
" in triple-underscores (e.g. `"___TYPE___"`), roughly similar to how
" Python names its "dunder methods" (e.g. `"__main__", "__call__"`). Declaring
" class members with names that use this format (e.g. declaring an object with
" a `"___SIZE___"` property) is strongly discouraged, though not disallowed.
"
" Typenames and identifiers shall not share the name of a reserved attribute.

let s:AttributesDict = {
    \ 'TYPE': '___TYPE___',
    \ 'DESTRUCTOR_LIST': '___DESTRUCTORS___',
    \ }

let s:Attributes = values(s:AttributesDict)

""
" Return a list of all of TypeVim's reserved attributes.
" @private
function! typevim#attribute#ATTRIBUTES() abort
  return deepcopy(s:Attributes)
endfunction

""
" Return all of TypeVim's reserved attributes, as a dictionary that can be
" queried using |has_key()|.
" @private
function! typevim#attribute#ATTRIBUTES_AS_DICT() abort
  if !exists('s:AttributesDict')
    let s:AttributesDict = {}
    for l:attr in s:Attributes
      let s:AttributesDict[l:attr] = 1
    endfor
  endif
  return deepcopy(s:AttributesDict)
endfunction

""
" Return the key used for storing an object's TYPE attribute.
" @private
function! typevim#attribute#TYPE() abort
  return s:AttributesDict['TYPE']
endfunction

""
" Return the key used for storing an object's list of destructor Funcrefs.
" @private
function typevim#attribute#DESTRUCTOR_LIST() abort
  return s:AttributesDict['DESTRUCTOR_LIST']
endfunction
