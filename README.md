## vim-parinfer

This is a vim plugin for using [parinfer](https://shaunlebron.github.io/parinfer/) to indent your clojure and lisp code.

It uses [Chris Oakman's awesome viml implementation](https://github.com/oakmac/parinfer-viml) under the hood

<h5 style="color: blue;"> pull requests // issues welcome </h5>

## Installation 

### using pathogen: 

```
cd ~/.vim/bundle
git clone git://github.com/bhurlow/vim-parinfer.git
```
### using Vundle:

add 

```
Plugin 'bhurlow/vim-parinfer'
```

to your `.vimrc`

run
 
```
:PluginInstall
```


## Mappings 

Parinfer is trigger on all TextChanged events within vim. If your version of
Vim does not support the 'TextChanged' autocommand event you may use the
following mapped commands:

- `>>` - indents s-expression
- `<<` - dedents s-expression
- `dd` - deletes line and balances parenthesis
- `p` - puts line and balances parenthesis






