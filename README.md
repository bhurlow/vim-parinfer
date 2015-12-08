## vim-parinfer

this is a vim plugin for using [parinfer](https://shaunlebron.github.io/parinfer/) to indent your clojure and lisp code.

## installation 

using pathogen: 

```
cd ~/.vim/bundle
git clone git://github.com/bhurlow/vim-parinfer.git
npm install 
```

## Notes

This is a really basic wrapper that shells out to a node.js server which parses the clj text using the parinfer js module target. This is cool because it allows us to upgrade the parinfer lib without changing any vim code. Also the less vimscript the better imho. Also you should know that the entire buffer is sent to the parser on every cursor move, so far this hasn't been an issue.

## Todos

- toggle between indent and paren mode
- catch parsing errors in node server
- set-able server port 



