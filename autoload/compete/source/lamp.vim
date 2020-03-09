let s:Position = vital#lamp#import('VS.LSP.Position')

let s:source_ids = []

"
" compete#source#lamp#register
"
function! compete#source#lamp#register() abort
  augroup compete#source#lamp#register
    autocmd!
    autocmd User lamp#server#initialized call timer_start(0, { -> s:source() })
    autocmd User lamp#server#exited call timer_start(0, { -> s:source() })
  augroup END
endfunction

"
" source
"
function! s:source() abort
  for l:source_id in s:source_ids
    call compete#source#lamp#unregister(l:source_id)
  endfor
  let s:source_ids = []

  let l:servers = lamp#server#registry#all()
  let l:servers = filter(l:servers, { _, server -> server.initialized })
  let l:servers = filter(l:servers, { _, server -> server.supports('capabilities.completionProvider') })
  let l:source_ids = map(copy(l:servers), { _, server ->
  \   compete#source#register({
  \     'name': l:server.name,
  \     'complete': function('s:complete', [l:server]),
  \     'filetypes': l:server.filetypes,
  \     'priority': 1,
  \     'trigger_chars': l:server.capability.get_completion_trigger_characters()
  \   })
  \ })
endfunction

"
" complete
"
function! s:complete(server, context, callback) abort
  let l:position = s:Position.cursor()
  let l:promise = a:server.request('textDocument/completion', {
  \   'textDocument': lamp#protocol#document#identifier(bufnr('%')),
  \   'position': l:position,
  \   'context': {
  \     'triggerKind': 2,
  \     'triggerCharacter': a:context.before_char,
  \   }
  \ })
  let l:promise = l:promise.catch(lamp#rescue({}))
  let l:promise = l:promise.then({ response -> s:on_response(a:server, a:context, a:callback, l:position, response) })
endfunction

"
" on_response
"
function! s:on_response(server, context, callback, position, response) abort
  if index([type([]), type({})], type(a:response)) == -1
    return
  endif

  call a:callback({
  \   'items': lamp#feature#completion#convert(a:server.name, a:position, a:response),
  \   'incomplete': get(a:response, 'isIncomplete', v:false),
  \ })
endfunction

