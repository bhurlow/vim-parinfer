
" VIM PARINFER PLUGIN
" v 1.0.0
" brian@brianhurlow.com

source plugin/parinfer_lib.vim
let g:parinfer_mode = "indent"
let g:parinfer_script_dir = resolve(expand("<sfile>:p:h:h"))

function! g:Select_full_form()

  "search backward for a ( on first col. Do not move the cursor
  let topline = search('^(', 'bn') - 1

  "find the matching pair. Do not move the cursor
  " TODO this still causes problems when the form is accidentally imbalacned 
  " parinfer can't fix this case b/c we don't find the proper form to evaluate
  call setpos('.', [0, topline + 1, 1, 0])
  let bottomline = searchpair('(','',')', 'n') + 1

  " could be a one line form?
  if bottomline == 1
    let bottomline = topline + 1
  endif

  let lines = getline(topline, bottomline)

  let section = join(lines, "\n")

  return [topline, bottomline, section]
  
endfunction

function! parinfer#draw(res, top, bottom)
  let lines = split(a:res, "\n")
  let counter = a:top + 1
  for line in lines
    call setline(counter, line)
    let counter += 1
  endfor
  redraw!
endfunction

function! g:ProcessForm()

  let save_cursor = getpos(".")
  let data = g:Select_full_form()
  let form = data[2]

  " TODO! pass in cursor to second ard
  let res = g:ParinferLib.IndentMode(form, {})
  let text = res.text

  call parinfer#draw(text, data[0], data[1])

  " reset cursor to where it was
  call setpos('.', save_cursor)

endfunction

function! parinfer#do_indent()
  normal! >>
  call g:ProcessForm()
endfunction

function! parinfer#do_undent()
  normal! <<
  call g:ProcessForm()
endfunction

function! parinfer#delete_line()
  delete
  call g:ProcessForm()
endfunction

function! parinfer#put_line()
  put
  call g:ProcessForm()
endfunction

" TODO toggle modes
com! -bar ToggleParinferMode cal parinfer#ToggleParinferMode() 

augroup parinfer
  autocmd!
  autocmd InsertLeave *.clj,*.cljs,*.cljc,*.edn call g:ProcessForm()
  autocmd FileType clojure nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure nnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>
  autocmd FileType clojure vnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>
  autocmd FileType clojure vnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>

  " so dd and p trigger paren rebalance
  autocmd FileType clojure nnoremap <buffer> dd :call parinfer#delete_line()<cr>
  autocmd FileType clojure nnoremap <buffer> p :call parinfer#put_line()<cr>
augroup END
