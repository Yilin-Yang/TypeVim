""
" @stylized TypeVim
" @section Introduction
" @library

try
  let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
  if !s:enter
    finish
  endif
catch /E117/ " Unknown function
  throw '(TypeVim) maktaba not detected! Please install "Google/vim-maktaba"!'
  finish
endtry
