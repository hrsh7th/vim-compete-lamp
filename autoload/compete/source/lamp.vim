let s:Position = vital#lamp#import('VS.LSP.Position')

let s:state = {
\   'ids': [],
\   'cancellation_token': lamp#cancellation_token(),
\ }

"
" compete#source#lamp#register
"
function! compete#source#lamp#register() abort
  augroup compete#source#lamp#register
    autocmd!
    autocmd User lamp#server#initialized call s:source()
    autocmd User lamp#server#exited call s:source()
  augroup END
endfunction

"
" source
"
function! s:source() abort
  for l:id in s:state.ids
    call compete#source#unregister(l:id)
  endfor
  let s:state.ids = []

  let l:servers = lamp#server#registry#all()
  let l:servers = filter(l:servers, { _, server -> !empty(server.initialized) })
  let l:servers = filter(l:servers, { _, server -> server.supports('capabilities.completionProvider') })
  let s:state.ids = map(copy(l:servers), { _, server ->
  \   compete#source#register({
  \     'name': server.name,
  \     'complete': function('s:complete', [server]),
  \     'filetypes': server.filetypes,
  \     'priority': 5,
  \     'trigger_chars': server.capability.get_completion_trigger_characters()
  \   })
  \ })
endfunction

"
" complete
"
function! s:complete(server, context, callback) abort
  call s:state.cancellation_token.cancel()
  let s:state.cancellation_token = lamp#cancellation_token()

  let l:compete_position = s:Position.cursor()
  let l:promise = a:server.request('textDocument/completion', {
  \   'textDocument': lamp#protocol#document#identifier(bufnr('%')),
  \   'position': l:compete_position,
  \   'context': {
  \     'triggerKind': 2,
  \     'triggerCharacter': a:context.before_char,
  \   }
  \ }, {
  \   'cancellation_token': s:state.cancellation_token,
  \ })
  let l:promise = l:promise.catch(lamp#rescue({}))
  let l:promise = l:promise.then({ response ->
  \   s:on_response(
  \     a:server,
  \     a:context,
  \     a:callback,
  \     l:compete_position,
  \     response
  \   )
  \ })
endfunction

"
" on_response
"
function! s:on_response(server, context, callback, complete_position, response) abort
  if index([type([]), type({})], type(a:response)) == -1
    return
  endif

  call a:callback({
  \   'items': lamp#feature#completion#convert(
  \     a:server.name,
  \     a:complete_position,
  \     a:response,
  \     {
  \       'menu': '[l]',
  \       'dup': 1,
  \     }
  \   ),
  \   'incomplete': type(a:response) == type({}) ? get(a:response, 'isIncomplete', v:false) : v:false,
  \ })
endfunction

