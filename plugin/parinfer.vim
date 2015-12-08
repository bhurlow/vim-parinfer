
if !exists("g:paredit_cmd")
  let g:paredit_cmd = "potion"
endif

function! SendStr()
  let page = join(getline(1,'$'), "\n")
  let body = substitute(page, '\n', '\\n', 'g')
  let jsonbody = '{"text": "' . body . '", "cursor": 10, "line": 10}'
  let cmd = "curl -s -X POST -d '" . jsonbody . "' localhost:8088"
  let res = system(cmd)
  redraw!
  " this makes handling \n chars much more sane
  " as opppsed to append()
  let @a = res
  normal! G
  execute "put a"
endfunction

nnoremap <buffer> <leader>bb :call SendStr()<cr>

