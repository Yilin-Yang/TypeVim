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
  if !exists(s:AttributesDict)
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
