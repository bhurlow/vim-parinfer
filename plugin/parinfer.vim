
" VIM PARINFER PLUGIN
" v 0.0.4
" brian@brianhurlow.com

source plugin/parinfer_lib.vim
let g:parinfer_mode = "indent"
let g:parinfer_script_dir = resolve(expand("<sfile>:p:h:h"))

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

function! parinfer#do_indent()
  normal! >>
  call parinfer#send_buffer()
endfunction

function! parinfer#do_undent()
  normal! <<
  call parinfer#send_buffer()
endfunction

com! -bar ToggleParinferMode cal parinfer#ToggleParinferMode() 

augroup parinfer
  autocmd!
  autocmd BufNewFile,BufReadPost *.clj,*.cljs,*.cljc call parinfer#start_server()
  autocmd InsertLeave *.clj,*.cljs,*.cljc call parinfer#send_buffer()
  autocmd VimLeavePre *.clj,*cljs,*.cljc call <sid> stop_server()
  autocmd FileType clojure nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure nnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  " stil considering these mappings
  "au TextChanged *.clj,*.cljc,*.cljs call parinfer#send_buffer()
  "au FileType clojure nnoremap <M-Tab> :call <sid>do_undent()<cr>
  "autocmd FileType clojure nnoremap <buffer> ]] /^(<CR>
  "autocmd FileType clojure nnoremap <buffer> [[ ?^(<CR>
augroup END
