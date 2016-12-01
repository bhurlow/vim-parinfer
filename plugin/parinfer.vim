
" VIM PARINFER PLUGIN
" v 0.0.4
" brian@brianhurlow.com

source plugin/parinfer_lib.vim
let g:parinfer_mode = "indent"
let g:parinfer_script_dir = resolve(expand("<sfile>:p:h:h"))

" recursive search might be good
"  searchpair('(', '', ')', 'r')
function! s:Select_full_form()

  "search backward for a ( on first col. Do not move the cursor
  let topline = search('^(', 'bn') - 1

  "find the matching pair. Do not move the cursor
  let bottomline = searchpair('(','',')', 'n') + 1

  let lines = getline(topline, bottomline)

  let section = join(lines, "\n")

  return [topline, bottomline, section]
  
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

function! g:ProcessForm()

  let data = s:Select_full_form()
  let form = data[2]

  echo form

  let res = g:ParinferLib.IndentMode(form, {})
  let text = res.text

  " call parinfer#draw(text, data[0], data[1])

endfunction

function! parinfer#do_indent()
  echo "INDE"
  normal! >>
  call g:ProcessForm()
endfunction

function! parinfer#do_undent()
  normal! <<
  call g:ProcessForm()
endfunction

com! -bar ToggleParinferMode cal parinfer#ToggleParinferMode() 

" for testing
nmap <Tab> :call parinfer#do_indent() <cr>
nmap <S-Tab> :call parinfer#do_undent()<cr>

augroup parinfer
  autocmd!
  autocmd InsertLeave *.clj,*.cljs,*.cljc,*.edn call parinfer#send_buffer()
  autocmd FileType clojure nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure nnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  autocmd FileType clojure vnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure vnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  " stil considering these mappings
  "au TextChanged *.clj,*.cljc,*.cljs,*.edn call parinfer#send_buffer()
  "au FileType clojure nnoremap <M-Tab> :call <sid>do_undent()<cr>
  "autocmd FileType clojure nnoremap <buffer> ]] /^(<CR>
  "autocmd FileType clojure nnoremap <buffer> [[ ?^(<CR>
augroup END
