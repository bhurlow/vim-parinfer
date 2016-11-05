
" VIM PARINFER PLUGIN
" v 0.0.4
" brian@brianhurlow.com

" TODO: let server port be global var

let g:parinfer_server_reachable = 0
"let g:parinfer_server_pid = 0
let g:parinfer_mode = "indent"
let g:parinfer_script_dir = resolve(expand("<sfile>:p:h:h"))

function! parinfer#ping_server()
  let cmd = 'curl -sw "%{http_code}" localhost:8088 -o /dev/null'
  return system(cmd)
endfunction

" recursive search might be good
"  searchpair('(', '', ')', 'r')
function! s:Select_full_form()

  let starting_line = line('.')
  let top_empty = 0
  let bottom_empty = 0

  " recursivley search for empty line above
  while !top_empty
    let l = getline(starting_line)
    if l == ""
      let top_empty = starting_line
      break
    elseif l == 1
      break
    endif
    let starting_line = starting_line -  1
  endwhile

  " b/c we know it was previously on an empty line
  let starting_line += 1
  
  while !bottom_empty
    let l = getline(starting_line)
    if l == ""
      let bottom_empty = starting_line
      break
    elseif l == 1
      break
    endif
    let starting_line = starting_line +  1
  endwhile

  let lines = getline(top_empty + 1, bottom_empty - 1)
  
  let section = join(lines, "\n")
  " for frag in lines
  "   let section = section . frag
  " endfor 
  
  return [top_empty, bottom_empty, section]
  
endfunction

function! parinfer#draw(res, top, bottom)

  let save_cursor = getpos(".")
  let lines = split(a:res, "\n")

  let counter = a:top + 1
  for line in lines
    call setline(counter, line)
    let counter += 1
  endfor
  redraw!

  " reset cursor to where it was
  call setpos('.', save_cursor)
endfunction

function! parinfer#write_tmp(body)
  redir! > /tmp/parifer_deck.txt
    echo a:body
  redir END
endfunction

" gotta make sure the clj string
" can be json parse-able 
" thanks:
" https://github.com/mattn/webapi-vim/blob/master/autoload/webapi/json.vim
function! parinfer#encode(data)
	let body = '"' . escape(a:data, '\"') . '"'
	let body = substitute(body, "\r", '\\r', 'g')
	let body = substitute(body, "\n", '\\n', 'g')
	let body = substitute(body, "\t", '\\t', 'g')
	let body = substitute(body, '\([[:cntrl:]]\)', '\=printf("\x%02d", char2nr(submatch(1)))', 'g')
	return iconv(body, &encoding, "utf-8")
endfunction

function! parinfer#send_buffer()

  "if !g:parinfer
  "  echo "parinfer server not started"
  "  return 0
  "endif
  
  let pos = getpos(".")
  let cursor = pos[0]
  let line = pos[1]

  let block = s:Select_full_form()
  let top_line = block[0]
  let bottom_line = block[1]
  let form = block[2]

  let body = parinfer#encode(form)

  let jsonbody = '{"text":' . body . ',"cursor":' . cursor . ',"line":' . line . '}'

  " avoiding passing var directly 
  " to shell cmd b/c of enconding crazyness
  let cmd = "cat /tmp/parifer_deck.txt | curl -s -X POST -d @- localhost:8088"
  let cmd = cmd . "/" . g:parinfer_mode

  " call silent here b/c redir normally
  " prints to page and file
  :silent call parinfer#write_tmp(jsonbody)

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
    echo "shell error"
  else
    call parinfer#draw(res, top_line, bottom_line)
  endif
  
endfunction

function! parinfer#start_server()
  let status = parinfer#ping_server()
  if status == 200 
    return 1
  else
    let cmd = "node " . g:parinfer_script_dir . "/server.js"  . " &> /tmp/parinfer.log & echo $!"
    let pid = system(cmd)
    " not sure why it gives 0 all the time: echo "SHELL CMD STATUS CODE" . v:shell_error
    " i'd like to detect of the server command returns an error code
    "let g:parinfer_server_pid = pid
    return pid
  endif
endfunction

function! parinfer#ToggleParinferMode()
  if g:parinfer_mode == "indent"
    let g:parinfer_mode = "paren"
  else
    let g:parinfer_mode = "indent"
  endif
endfunction

function! parinfer#stop_server()
  let cmd = "kill -9 " . g:parinfer_server_pid
  let res = system(cmd)
endfunction

function! parinfer#do_indent()
  normal! >>
  call parinfer#send_buffer()
endfunction

function! parinfer#do_undent()
  normal! <<
  call parinfer#send_buffer()
endfunction

"nnoremap <buffer> <leader>bb :call parinfer#pasend_buffer()<cr>
com! -bar ToggleParinferMode cal parinfer#ToggleParinferMode() 

augroup parinfer
  autocmd!
  autocmd BufNewFile,BufReadPost *.clj,*.cljs,*.cljc,*.edn,*.rkt call parinfer#start_server()
  autocmd InsertLeave *.clj,*.cljs,*.cljc,*.edn,*.rkt call parinfer#send_buffer()
  autocmd VimLeavePre *.clj,*cljs,*.cljc,*.edn,*.rkt call <sid> stop_server()
  autocmd FileType clojure,racket nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure,racket nnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  autocmd FileType clojure,racket vnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure,racket vnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  " stil considering these mappings
  "au TextChanged *.clj,*.cljc,*.cljs,*.edn call parinfer#send_buffer()
  "au FileType clojure nnoremap <M-Tab> :call <sid>do_undent()<cr>
  "autocmd FileType clojure nnoremap <buffer> ]] /^(<CR>
  "autocmd FileType clojure nnoremap <buffer> [[ ?^(<CR>
augroup END
