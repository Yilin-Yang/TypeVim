""
" @dict Doer
" A generic Doer implementation, for use with @dict(Promise). Designed for
" ease of use alongside neovim's |job-control| and vim's |channel| interface.
"
" As of the time of writing, only neovim |job-control| is officially supported.

let s:typename = 'Doer'

""
" @dict Doer
" Return a new Doer.
"
" Note that a Doer will not actually start running until a call to
" @function(Doer.SetCallbacks), to ensure that the job does not finish before
" a success (or error) handler has been attached.
function! typevim#Doer#New(Handler) abort
  call maktaba#ensure#IsFuncref(a:Handler)
  let l:new = {
      \ '__job_id': -1,
      \ 'SetCallbacks': typevim#make#Member('SetCallbacks'),
      \ 'OnNvimJobEvent': typevim#make#Member('OnNvimJobEvent'),
      \ 'OnVimMsgRecv': typevim#make#Member('OnVimMsgRecv'),
      \ 'HandleJobCallback': a:Handler
      \ }
  " TODO start a job, differently, depending on whether this is vim or neovim
  return typevim#make#Class(l:new)
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" @dict Doer
" Set {Resolve} and {Reject} callbacks on this Doer, to be called when this
" Doer resolves or rejects after doing its assigned task.
function! typevim#Doer#SetCallbacks(Resolve, Reject) dict abort
  call s:CheckType(l:self)
  let l:self['__Resolve'] = a:Resolve
  let l:self['__Reject'] = a:Reject
endfunction

""
" @dict Doer
" Callback function to be provided to a neovim |job|. Essentially a wrapper
" that just calls the `HandleJobCallback` function provided in the constructor.
"
" {job_id} is the job's |job-id|.
"
" The type of {data} will vary based on the kind of event that triggered the
" callback. Input from `stdout` will typically be a list of strings containing each line
" of output from the job, for instance, while `exit` events will provide an
" exit code.
"
" {event} is a string describing the type of event, generally `"stdout"`,
" `"stderr"`, `"stdin"`, or `"data"`, or `"exit"`.
"
" See |channel-callback| for more details.
function! typevim#Doer#OnNvimJobEvent(job_id, data, event) dict abort
  call s:CheckType(l:self)
  call l:self.HandleJobCallback(a:job_id, a:data, a:event)
endfunction

""
" @dict Doer
" Callback function to be provided as a vim |channel-callback|. TODO
function! typevim#Doer#OnVimMsgRecv(chan_id, msg) dict abort
endfunction
