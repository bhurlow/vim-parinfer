
" VIM PARINFER PLUGIN
" v 0.0.3
" brian@brianhurlow.com

" TODO: let server port be global var

let g:parinfer_server_reachable = 0
let g:parinfer_server_pid = 0
let g:parinfer_mode = "indent"
let g:parinfer_script_dir = resolve(expand("<sfile>:p:h:h"))

" not currently used 
function! s:ping_server()
  let cmd = 'curl -sw "%{http_code}" localhost:8088 -o /dev/null'
  return system(cmd)
endfunction

function! s:draw(res)
  redraw!
  let save_cursor = getpos(".")
  normal! ggdG
  let @a = a:res
  execute "put a"
  normal! ggdd
  call setpos('.', save_cursor)
endfunction

function! s:write_tmp(body)
  redir! > /tmp/parifer_deck.txt
    echo a:body
  redir END
endfunction

" gotta make sure the clj string
" can be json parse-able 
" thanks:
" https://github.com/mattn/webapi-vim/blob/master/autoload/webapi/json.vim
function! s:encode(data)
	let body = '"' . escape(a:data, '\"') . '"'
	let body = substitute(body, "\r", '\\r', 'g')
	let body = substitute(body, "\n", '\\n', 'g')
	let body = substitute(body, "\t", '\\t', 'g')
	let body = substitute(body, '\([[:cntrl:]]\)', '\=printf("\x%02d", char2nr(submatch(1)))', 'g')
	return iconv(body, &encoding, "utf-8")
endfunction

function! s:send_buffer()

  if !g:parinfer_server_pid
    echo "parinfer server not started"
    return 0
  endif
  
  let pos = getpos(".")
  let cursor = pos[0]
  let line = pos[1]

  let page = join(getline(1,'$'), "\n")
  let body = s:encode(page)

  let jsonbody = '{"text":' . body . ',"cursor":' . cursor . ',"line":' . line . '}'

  " avoiding passing var directly 
  " to shell cmd b/c of enconding crazyness
  let cmd = "cat /tmp/parifer_deck.txt | curl -s -X POST -d @- localhost:8088"
  let cmd = cmd . "/" . g:parinfer_mode

  " call silent here b/c redir normally
  " prints to page and file
  :silent call s:write_tmp(jsonbody)

  let res = ""

  try
    let res = system(cmd)
  catch
    echom "parinfer curl exec error"
    echom "error code" . v:exception
  finally
    " echom "finally block"
  endtry

  " if our shell command fails 
  " don't draw the res
  if v:shell_error != 0
    call s:draw(res)
  else
    call s:draw(res)
  endif
  
endfunction

function! s:start_server()
  let status = s:ping_server()
  if status == 200 
    return 1
  else
    let cmd = "node " . g:parinfer_script_dir . "/server.js"  . " &> /tmp/parinfer.log & echo $!"
    let pid = system(cmd)
    " not sure why it gives 0 all the time: echo "SHELL CMD STATUS CODE" . v:shell_error
    " i'd like to detect of the server command returns an error code
    let g:parinfer_server_pid = pid
    return pid
  endif
endfunction

function ToggleParinferMode()
  if g:parinfer_mode == "indent"
    let g:parinfer_mode = "paren"
  else
    let g:parinfer_mode = "indent"
  endif
endfunction

function! s:stop_server()
  let cmd = "kill -9 " . g:parinfer_server_pid
  let res = system(cmd)
endfunction

function! s:do_indent()
  normal! >>
  call s:send_buffer()
endfunction

function! s:do_undent()
  normal! <<
  call s:send_buffer()
endfunction

augroup parinfer
  autocmd!
  autocmd BufNewFile,BufReadPost *.clj setfiletype clojure
  autocmd BufNewFile,BufReadPost *.clj call s:start_server()
  nnoremap <buffer> <leader>bb :call <sid>send_buffer()<cr>
  au InsertLeave *.clj call <sid>send_buffer()
  au VimLeavePre *.clj call <sid>stop_server()
  au FileType clojure nnoremap <Tab> :call <sid>do_indent()<cr>
  au FileType clojure nnoremap <S-Tab> :call <sid>do_undent()<cr>
  au FileType clojure nnoremap w :call <sid>do_indent()<cr>
  au FileType clojure nnoremap q :call <sid>do_undent()<cr>
augroup END

