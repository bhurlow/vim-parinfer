
" VIM PARINFER PLUGIN
" v 1.0.1
" brian@brianhurlow.com

let g:parinfer_script_dir = resolve(expand("<sfile>:p:h:h"))
let g:parinfer_mode = "indent"

function! g:Select_full_form()

let delims = {
      \ 'parens': {'left': '(', 'right': ')'},
      \ 'curlies': {'left': '{', 'right': '}'},
      \ 'brackets': {'left': '[', 'right': ']'}
      \}

  let full_form_delimiters = delims['parens']

  "search backward for a ( on first col. Do not move the cursor
  let topline = search('^(', 'bn') 

  if topline == 0
    let topline = search('^{', 'bn')
    let full_form_delimiters = delims['curlies']
  endif

  if topline == 0
    let topline = search('^[', 'bn')
    let full_form_delimiters = delims['brackets']
  endif

  let current_line = getline('.')

  " handle case when cursor is ontop of start mark
  " (search backwards misses this)
  if current_line[0] == '('
    let topline = line('.')
  elseif current_line[0] == '{'
    let topline = line('.')
    let full_form_delimiters = delims['curlies']
  elseif current_line[0] == '['
    let topline = line('.')
    let full_form_delimiters = delims['brackets']
  endif

  if topline == 0
    throw 'No top-level form found!'
  endif

  " temp, set cursor to form start
  call setpos('.', [0, topline, 1, 0])

  " next paren match 
  " only usable when parens are balanced
  let matchline = searchpair(full_form_delimiters['left'],'',full_form_delimiters['right'], 'nW') 

  let bottomline = search('^' . full_form_delimiters['left'], 'nW') - 1

  " if no subsequent form can be found
  " assume we've hit the bottom of the file
  if bottomline == -1
    let bottomline = line('$')
  endif

  let lines = getline(topline, bottomline)
  let section = join(lines, "\n")
  return [topline, bottomline, section]
  
endfunction

function! parinfer#draw(res, top, bottom)
  let lines = split(a:res, "\n")
  let counter = a:top 
  for line in lines
    call setline(counter, line)
    let counter += 1
  endfor
endfunction

function! parinfer#process_form()

  let save_cursor = getpos(".")
  let data = g:Select_full_form()
  let form = data[2]

  " TODO! pass in cursor to second ard
  let res = parinfer_lib#IndentMode(form, {})
  let text = res.text

  call parinfer#draw(text, data[0], data[1])

  " reset cursor to where it was
  call setpos('.', save_cursor)

endfunction

function! parinfer#do_indent()
  normal! >>
  call parinfer#process_form()
endfunction

function! parinfer#do_undent()
  normal! <<
  call parinfer#process_form()
endfunction

function! parinfer#delete_line()
  delete
  call parinfer#process_form()
endfunction

function! parinfer#put_line()
  put
  call parinfer#process_form()
endfunction

function! parinfer#del_char()
  let pos = getpos('.')
  let row = pos[2]
  let line = getline('.')

  let newline = ""
  let mark = row - 2

  if mark <= 0
    let newline = line[1:len(line) - 1]
  elseif 
    let start = line[0:mark]
    let end = line[row:len(line)]
    let newline = start . end
  endif

  call setline('.', newline)
  call parinfer#process_form()
endfunction

" TODO toggle modes
com! -bar ToggleParinferMode cal parinfer#ToggleParinferMode() 

augroup parinfer
  autocmd!
  autocmd InsertLeave *.clj,*.cljs,*.cljc,*.edn,*.rkt,*.lisp call parinfer#process_form()
  autocmd FileType clojure,racket,lisp nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure,racket,lisp nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure,racket,lisp nnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  autocmd FileType clojure,racket,lisp vnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure,racket,lisp vnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>

  " so dd and p trigger paren rebalance
  autocmd FileType clojure,racket,lisp nnoremap <buffer> dd :call parinfer#delete_line()<cr>
  autocmd FileType clojure,racket,lisp nnoremap <buffer> p :call parinfer#put_line()<cr>
  " autocmd FileType clojure nnoremap <buffer> x :call parinfer#del_char()<cr>
augroup END
