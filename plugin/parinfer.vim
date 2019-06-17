
" VIM PARINFER PLUGIN
" v 1.1.0
" brian@brianhurlow.com

let g:_VIM_PARINFER_DEFAULTS = {
    \ 'globs':      ['*.clj', '*.cljs', '*.cljc', '*.edn', '*.hl', '*.lisp', '*.rkt', '*.ss', '*.lfe'],
    \ 'filetypes':  ['clojure', 'racket', 'lisp', 'scheme', 'lfe'],
    \ 'mode':       "indent",
    \ 'script_dir': resolve(expand("<sfile>:p:h:h"))
    \ }

for s:key in keys(g:_VIM_PARINFER_DEFAULTS)
    if !exists('g:vim_parinfer_' . s:key)
        let g:vim_parinfer_{s:key} = copy(g:_VIM_PARINFER_DEFAULTS[s:key])
    endif
endfor

runtime autoload/parinfer_lib.vim

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

function! parinfer#process_form_insert()
  if strcharpart(getline('.')[col('.') - 2:], 0, 1) == " "
    return
  endif

  call parinfer#process_form()
endfunction

function! parinfer#process_form()
  let save_cursor = getpos(".")
  let data = g:Select_full_form()
  let form = data[2]

  " TODO! pass in cursor to second ard
  let res = g:ParinferLib.IndentMode(form, {})
  let text = res.text

  if form != text
    call parinfer#draw(text, data[0], data[1])
  endif

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
  execute "autocmd InsertLeave " . join(g:vim_parinfer_globs, ",") . " call parinfer#process_form()"
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " nnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>"
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " nnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>"
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " vnoremap <buffer> <Tab> :call parinfer#do_indent()<cr>"
  execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " vnoremap <buffer> <S-Tab> :call parinfer#do_undent()<cr>"

  if exists('##TextChangedI')
    execute "autocmd TextChangedI " . join(g:vim_parinfer_globs, ",") . " call parinfer#process_form_insert()"
  endif

  if exists('##TextChanged')
    execute "autocmd TextChanged " . join(g:vim_parinfer_globs, ",") . " call parinfer#process_form()"
  else
    " dd and p trigger paren rebalance
    execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " nnoremap <buffer> dd :call parinfer#delete_line()<cr>"
    execute "autocmd FileType " . join(g:vim_parinfer_filetypes, ",") . " nnoremap <buffer> p  :call parinfer#put_line()<cr>"
  endif
augroup END
