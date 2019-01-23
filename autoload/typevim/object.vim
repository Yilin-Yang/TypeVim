""
" @private
function! typevim#object#Destroy() abort dict
  let l:destructors = l:self['DESTRUCTORS']
  let l:i = len(l:destructors) - 1
  while l:i ># -1
    let l:Destructor = l:destructors[l:i]
    call function(l:Destructor, l:self)
    let l:i -= 1
  endwhile
endfunction
