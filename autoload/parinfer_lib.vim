"" parinfer.vim - a Parinfer implementation in Vimscript
"" v0.2.0
"" https://github.com/oakmac/parinfer-viml
""
"" More information about Parinfer can be found here:
"" http://shaunlebron.github.io/parinfer/
""
"" Copyright (c) 2016, Chris Oakman
"" Released under the ISC license
"" https://github.com/oakmac/parinfer-viml/blob/master/LICENSE.md

""------------------------------------------------------------------------------
"" Constants / Predicates
""------------------------------------------------------------------------------

let s:SENTINEL_NULL = -999

let s:INDENT_MODE = 'INDENT_MODE'
let s:PAREN_MODE = 'PAREN_MODE'

let s:BACKSLASH = '\'
let s:BLANK_SPACE = ' '
let s:DOUBLE_SPACE = '  '
let s:DOUBLE_QUOTE = '"'
let s:NEWLINE = "\n"
let s:SEMICOLON = ';'
let s:TAB = "\t"

let s:PARENS = {}
let s:PARENS['('] = ')'
let s:PARENS['{'] = '}'
let s:PARENS['['] = ']'
let s:PARENS[')'] = '('
let s:PARENS['}'] = '{'
let s:PARENS[']'] = '['

" Parser 'states'
let s:CODE = '*'
let s:COMMENT = ';'
let s:STRING = '"'

function! s:IsCloseParen(ch)
    return a:ch ==# ')' || a:ch ==# '}' || a:ch ==# ']'
endfunction

""------------------------------------------------------------------------------
"" Result Structure
""------------------------------------------------------------------------------

function! s:CreateInitialResult(text, mode, options)
    let l:result = {}

    let l:result.mode = a:mode

    let l:result.origText = a:text
    let l:result.origLines = split(a:text, s:NEWLINE, 1)

    let l:result.lines = []
    let l:result.lineNo = -1
    let l:result.ch = ''
    let l:result.x = 0

    let l:result.parenStack = []

    let l:result.parenTrailLineNo = s:SENTINEL_NULL
    let l:result.parenTrailStartX = s:SENTINEL_NULL
    let l:result.parenTrailEndX = s:SENTINEL_NULL
    let l:result.parenTrailOpeners = []

    let l:result.cursorX = get(a:options, 'cursorX', s:SENTINEL_NULL)
    let l:result.cursorLine = get(a:options, 'cursorLine', s:SENTINEL_NULL)
    let l:result.cursorDx = get(a:options, 'cursorDx', s:SENTINEL_NULL)

    let l:result.state = s:CODE
    let l:result.commentX = s:SENTINEL_NULL

    let l:result.quoteDanger = 0
    let l:result.trackingIndent = 0
    let l:result.skipChar = 0
    let l:result.success = 0

    let l:result.maxIndent = s:SENTINEL_NULL
    let l:result.indentDelta = 0

    let l:result.error = s:SENTINEL_NULL
    let l:result.errorPosCache = {}

    return l:result
endfunction

""------------------------------------------------------------------------------
"" Errors
""------------------------------------------------------------------------------

let s:ERROR_QUOTE_DANGER = 'quote-danger'
let s:ERROR_EOL_BACKSLASH = 'eol-backslash'
let s:ERROR_UNCLOSED_QUOTE = 'unclosed-quote'
let s:ERROR_UNCLOSED_PAREN = 'unclosed-paren'

let s:ERROR_MESSAGES = {}
let s:ERROR_MESSAGES[s:ERROR_QUOTE_DANGER] = 'Quotes must balanced inside comment blocks.'
let s:ERROR_MESSAGES[s:ERROR_EOL_BACKSLASH] = 'Line cannot end in a hanging backslash.'
let s:ERROR_MESSAGES[s:ERROR_UNCLOSED_QUOTE] = 'String is missing a closing quote.'
let s:ERROR_MESSAGES[s:ERROR_UNCLOSED_PAREN] = 'Unmatched open-paren.'


function! s:CacheErrorPos(result, errorName, lineNo, x)
    let a:result.errorPosCache[a:errorName] = {'lineNo': a:lineNo, 'x': a:x,}
endfunction

function! s:CreateError(result, errorName, lineNo, x)
    "" TODO: figure out how to attach information to a Vimscript error
    return 'PARINFER_ERROR'
endfunction


""------------------------------------------------------------------------------
"" String Operations
""------------------------------------------------------------------------------


function! s:InsertWithinString(orig, idx, insert)
    return strpart(a:orig, 0, a:idx) . a:insert . strpart(a:orig, a:idx)
endfunction


function! s:RemoveWithinString(orig, startIdx, endIdx)
    return strpart(a:orig, 0, a:startIdx) . strpart(a:orig, a:endIdx)
endfunction


""------------------------------------------------------------------------------
"" Line operations
""------------------------------------------------------------------------------


function! s:InsertWithinLine(result, lineNo, idx, insert)
    let a:result.lines[a:lineNo] = s:InsertWithinString(a:result.lines[a:lineNo], a:idx, a:insert)
endfunction


function! s:ReplaceWithinLine(result, lineNo, startIdx, endIdx, replace)
    let a:result.lines[a:lineNo] = strpart(a:result.lines[a:lineNo], 0, a:startIdx) . a:replace . strpart(a:result.lines[a:lineNo], a:endIdx)
endfunction


function! s:RemoveWithinLine(result, lineNo, startIdx, endIdx)
    let a:result.lines[a:lineNo] = s:RemoveWithinString(a:result.lines[a:lineNo], a:startIdx, a:endIdx)
endfunction


function! s:InitLine(result, line)
    let a:result.x = 0
    let a:result.lineNo = a:result.lineNo + 1
    call add(a:result.lines, a:line)

    "" reset line-specific state
    let a:result.commentX = s:SENTINEL_NULL
    let a:result.indentDelta = 0
endfunction


function! s:CommitChar(result, origCh)
    if a:origCh !=# a:result.ch
        call s:ReplaceWithinLine(a:result, a:result.lineNo, a:result.x, a:result.x + strlen(a:origCh), a:result.ch)
    endif
    let a:result.x += strlen(a:result.ch)
endfunction


""------------------------------------------------------------------------------
"" Misc Util
""------------------------------------------------------------------------------

"" NOTE: this should be a variadic function, but for Parinfer's purposes it only
""       needs to be two arity
function! s:Max(x, y)
    if a:y > a:x
        return a:y
    endif
    return a:x
endfunction


function! s:Clamp(valN, minN, maxN)
    let l:returnVal = a:valN
    if a:minN != s:SENTINEL_NULL
        if a:minN > l:returnVal
            let l:returnVal = a:minN
        endif
    endif

    if a:maxN != s:SENTINEL_NULL
        if a:maxN < l:returnVal
            let l:returnVal = a:maxN
        endif
    endif

    return l:returnVal
endfunction


function! s:Peek(arr)
    return get(a:arr, -1, s:SENTINEL_NULL)
endfunction


"" removes the last item from a list
"" if the list is already empty, does nothing
"" returns the modified (or empty) array
function! s:Pop(arr)
    if len(a:arr) == 0
        return []
    endif
    return a:arr[0:-2]
endfunction


""------------------------------------------------------------------------------
"" Character functions
""------------------------------------------------------------------------------


function! s:IsValidCloseParen(parenStack, ch)
    return len(a:parenStack) ? s:Peek(a:parenStack).ch ==# s:PARENS[a:ch] : 0
endfunction


function! s:OnOpenParen(result)
    call add(a:result.parenStack, { "lineNo": a:result.lineNo
                                \ , "x": a:result.x
                                \ , "ch": a:result.ch
                                \ , "indentDelta": a:result.indentDelta
                                \ })
endfunction


function! s:OnMatchedCloseParen(result)
    let l:opener = s:Peek(a:result.parenStack)
    let a:result.parenTrailEndX = a:result.x + 1
    call add(a:result.parenTrailOpeners, l:opener)
    let a:result.maxIndent = l:opener.x
    let a:result.parenStack = s:Pop(a:result.parenStack)
endfunction


function! s:OnUnmatchedCloseParen(result)
    let a:result.ch = ''
endfunction


function! s:OnCloseParen(result)
    if s:IsValidCloseParen(a:result.parenStack, a:result.ch)
        call s:OnMatchedCloseParen(a:result)
    else
        call s:OnUnmatchedCloseParen(a:result)
    endif
endfunction


function! s:OnTab(result)
    let a:result.ch = s:DOUBLE_SPACE
endfunction


function! s:OnSemicolon(result)
    let a:result.state = s:COMMENT
    let a:result.commentX = a:result.x
endfunction


function! s:OnCommentNewline(result)
    let a:result.state = s:CODE
    let a:result.ch = ''
endfunction


function! s:OnNewline(result)
    let a:result.ch = ''
endfunction


function! s:OnCodeQuote(result)
    let a:result.state = s:STRING
    call s:CacheErrorPos(a:result, s:ERROR_UNCLOSED_QUOTE, a:result.lineNo, a:result.x)
endfunction


function! s:OnStringQuote(result)
    let a:result.state = s:CODE
endfunction


function! s:OnCommentQuote(result)
    let a:result.quoteDanger = ! a:result.quoteDanger
    if a:result.quoteDanger
        call s:CacheErrorPos(a:result, s:ERROR_QUOTE_DANGER, a:result.lineNo, a:result.x)
    endif
endfunction


function! s:OnBackslashNewline(result)
    throw s:CreateError(a:result, s:ERROR_EOL_BACKSLASH, a:result.lineNo, a:result.x - 1)
endfunction

let s:DISPATCH =
  \ { '*(': function("<SID>OnOpenParen")
  \ , '*[': function("<SID>OnOpenParen")
  \ , '*{': function("<SID>OnOpenParen")
  \ , '*)': function("<SID>OnCloseParen")
  \ , '*]': function("<SID>OnCloseParen")
  \ , '*}': function("<SID>OnCloseParen")
  \ , '*"': function("<SID>OnCodeQuote")
  \ , '*;': function("<SID>OnSemicolon")
  \ , "*\t": function("<SID>OnTab")
  \ , "*\n": function("<SID>OnNewline")
  \ , "*\\\n": function("<SID>OnBackslashNewline")
  \ , ';"': function("<SID>OnCommentQuote")
  \ , ";\n": function("<SID>OnCommentNewline")
  \ , '""': function("<SID>OnStringQuote")
  \ , "\"\n": function("<SID>OnNewline")
  \ }

""------------------------------------------------------------------------------
"" Cursor functions
""------------------------------------------------------------------------------


function! s:IsCursorOnLeft(result)
    return a:result.lineNo == a:result.cursorLine &&
         \ a:result.cursorX != s:SENTINEL_NULL &&
         \ a:result.cursorX <= a:result.x
endfunction


function! s:IsCursorOnRight(result, x)
    return a:result.lineNo == a:result.cursorLine &&
         \ a:result.cursorX != s:SENTINEL_NULL &&
         \ a:x != s:SENTINEL_NULL &&
         \ a:result.cursorX > a:x
endfunction


function! s:IsCursorInComment(result)
    return s:IsCursorOnRight(a:result, a:result.commentX)
endfunction


function! s:HandleCursorDelta(result)
    let l:hasCursorDelta = a:result.cursorDx != s:SENTINEL_NULL &&
                         \ a:result.cursorLine == a:result.lineNo &&
                         \ a:result.cursorX == a:result.x

    if l:hasCursorDelta
        let a:result.indentDelta = a:result.indentDelta + a:result.cursorDx
    endif
endfunction


""------------------------------------------------------------------------------
"" Paren Trail functions
""------------------------------------------------------------------------------


function! s:UpdateParenTrailBounds(result)
    if a:result.state ==# s:CODE &&
      \ a:result.ch =~ '[^)\]}]' &&
      \ (a:result.ch !=# ' ' || (a:result.x > 0 && a:result.lines[a:result.lineNo][a:result.x - 1] ==# '\'))
        call extend(a:result, { "parenTrailLineNo": a:result.lineNo
                            \ , "parenTrailStartX": a:result.x + strlen(a:result.ch)
                            \ , "parenTrailEndX": a:result.x + strlen(a:result.ch)
                            \ , "parenTrailOpeners": []
                            \ , "maxIndent": s:SENTINEL_NULL
                            \ })
    endif
endfunction


function! s:ClampParenTrailToCursor(result)
    let l:startX = a:result.parenTrailStartX
    let l:endX = a:result.parenTrailEndX

    let l:isCursorClamping = s:IsCursorOnRight(a:result, l:startX) &&
                           \ ! s:IsCursorInComment(a:result)

    if l:isCursorClamping
        let l:newStartX = s:Max(l:startX, a:result.cursorX)
        let l:newEndX = s:Max(l:endX, a:result.cursorX)

        let l:line = a:result.lines[a:result.lineNo]
        let l:removeCount = 0
        let l:i = l:startX
        while l:i < l:newStartX
            if s:IsCloseParen(l:line[l:i])
                let l:removeCount = l:removeCount + 1
            endif
            let l:i = l:i + 1
        endwhile

        if l:removeCount > 0
            let a:result.parenTrailOpeners = a:result.parenTrailOpeners[l:removeCount : ]
        endif
        let a:result.parenTrailStartX = l:newStartX
        let a:result.parenTrailEndX = l:newEndX
    endif
endfunction


function! s:RemoveParenTrail(result)
    let l:startX = a:result.parenTrailStartX
    let l:endX = a:result.parenTrailEndX

    if l:startX == l:endX
        return
    endif

    let l:openers = a:result.parenTrailOpeners
    let a:result.parenStack = a:result.parenStack + reverse(l:openers)
    let a:result.parenTrailOpeners = []

    call s:RemoveWithinLine(a:result, a:result.lineNo, l:startX, l:endX)
endfunction


function! s:CorrectParenTrail(result, indentX)
    let l:parens = ''

    while len(a:result.parenStack) > 0
        let l:opener = s:Peek(a:result.parenStack)
        if l:opener.x >= a:indentX
            let a:result.parenStack = s:Pop(a:result.parenStack)
            let l:parens = l:parens . s:PARENS[l:opener.ch]
        else
            break
        endif
    endwhile

    call s:InsertWithinLine(a:result, a:result.parenTrailLineNo, a:result.parenTrailStartX, l:parens)
endfunction


function! s:CleanParenTrail(result)
    let l:startX = a:result.parenTrailStartX
    let l:endX = a:result.parenTrailEndX

    if l:startX == l:endX || a:result.lineNo != a:result.parenTrailLineNo
        return
    endif

    let l:line = a:result.lines[a:result.lineNo]
    let l:newTrail = ''
    let l:spaceCount = 0
    let l:i = l:startX
    while l:i < l:endX
        if s:IsCloseParen(l:line[l:i])
            let l:newTrail = l:newTrail . l:line[l:i]
        else
            let l:spaceCount = l:spaceCount + 1
        endif
        let l:i = l:i + 1
    endwhile

    if l:spaceCount > 0
        call s:ReplaceWithinLine(a:result, a:result.lineNo, l:startX, l:endX, l:newTrail)
        let a:result.parenTrailEndX = a:result.parenTrailEndX - l:spaceCount
    endif
endfunction


function! s:AppendParenTrail(result)
    let l:opener = a:result.parenStack[-1]
    let a:result.parenStack = s:Pop(a:result.parenStack)
    let l:closeCh = s:PARENS[l:opener.ch]

    let a:result.maxIndent = l:opener.x
    call s:InsertWithinLine(a:result, a:result.parenTrailLineNo, a:result.parenTrailEndX, l:closeCh)
    let a:result.parenTrailEndX = a:result.parenTrailEndX + 1
endfunction


function! s:FinishNewParenTrail(result)
    if a:result.mode ==# s:INDENT_MODE
        call s:ClampParenTrailToCursor(a:result)
        call s:RemoveParenTrail(a:result)
    elseif a:result.mode ==# s:PAREN_MODE
        if a:result.lineNo != a:result.cursorLine
            call s:CleanParenTrail(a:result)
        endif
    endif
endfunction

""------------------------------------------------------------------------------
"" Indentation functions
""------------------------------------------------------------------------------

function! s:CorrectIndent(result)
    let l:origIndent = a:result.x
    let l:newIndent = l:origIndent
    let l:minIndent = 0
    let l:maxIndent = a:result.maxIndent

    if len(a:result.parenStack) != 0
        let l:opener = s:Peek(a:result.parenStack)
        let l:minIndent = l:opener.x + 1
        let l:newIndent = l:newIndent + l:opener.indentDelta
    endif

    let l:newIndent = s:Clamp(l:newIndent, l:minIndent, l:maxIndent)

    if l:newIndent != l:origIndent
        let l:indentStr = repeat(s:BLANK_SPACE, l:newIndent)
        call s:ReplaceWithinLine(a:result, a:result.lineNo, 0, l:origIndent, l:indentStr)
        let a:result.x = l:newIndent
        let a:result.indentDelta = a:result.indentDelta + l:newIndent - l:origIndent
    endif
endfunction


function! s:OnProperIndent(result)
    let a:result.trackingIndent = 0

    if a:result.quoteDanger
        throw s:CreateError(a:result, s:ERROR_QUOTE_DANGER, s:SENTINEL_NULL, s:SENTINEL_NULL)
    endif

    if a:result.mode ==# s:INDENT_MODE
        call s:CorrectParenTrail(a:result, a:result.x)
    elseif a:result.mode ==# s:PAREN_MODE
        call s:CorrectIndent(a:result)
    endif
endfunction


function! s:OnLeadingCloseParen(result)
    let a:result.skipChar = 1
    let a:result.trackingIndent = 1

    if a:result.mode ==# s:PAREN_MODE
        if s:IsValidCloseParen(a:result.parenStack, a:result.ch)
            if s:IsCursorOnLeft(a:result)
                let a:result.skipChar = 0
                call s:OnProperIndent(a:result)
            else
                call s:AppendParenTrail(a:result)
            endif
        endif
    endif
endfunction


function! s:OnIndent(result)
    if s:IsCloseParen(a:result.ch)
        call s:OnLeadingCloseParen(a:result)
    elseif a:result.ch ==# s:SEMICOLON
        let a:result.trackingIndent = 0
    elseif a:result.ch !=# s:NEWLINE
        call s:OnProperIndent(a:result)
    endif
endfunction


""------------------------------------------------------------------------------
"" High-level processing functions
""------------------------------------------------------------------------------

function! s:ProcessChar(result, ch)
    let a:result.ch = a:ch
    let a:result.skipChar = 0

    if a:result.mode ==# s:PAREN_MODE
        call s:HandleCursorDelta(a:result)
    endif

    if a:result.trackingIndent && a:ch !=# s:BLANK_SPACE && a:ch !=# s:TAB
        call s:OnIndent(a:result)
    endif

    if a:result.skipChar
        let a:result.ch = ''
    else
        call call(get(s:DISPATCH, a:result.state . a:result.ch, function("type")), [a:result])
        call s:UpdateParenTrailBounds(a:result)
    endif

    call s:CommitChar(a:result, a:ch)
endfunction

function! s:ProcessLine(result, line)
    call s:InitLine(a:result, a:line)

    if a:result.mode ==# s:INDENT_MODE
        let a:result.trackingIndent = len(a:result.parenStack) != 0 &&
                                    \ a:result.state !=# s:STRING
    elseif a:result.mode ==# s:PAREN_MODE
        let a:result.trackingIndent = a:result.state !=# s:STRING
    endif

    call map(split(a:line . s:NEWLINE, '\%([ ()[\]{}";\t\n]\|\\[.\n]\|[^ ()[\]{}";\\\t\n]\+\)\zs'), 's:ProcessChar(a:result, v:val)')

    if a:result.lineNo == a:result.parenTrailLineNo
        call s:FinishNewParenTrail(a:result)
    endif
endfunction


function! s:FinalizeResult(result)
    if a:result.quoteDanger
        throw s:CreateError(a:result, s:ERROR_QUOTE_DANGER, s:SENTINEL_NULL, s:SENTINEL_NULL)
    endif

    if a:result.state ==# s:STRING
        throw s:CreateError(a:result, s:ERROR_UNCLOSED_QUOTE, s:SENTINEL_NULL, s:SENTINEL_NULL)
    endif

    if len(a:result.parenStack) != 0
        if a:result.mode ==# s:PAREN_MODE
            let l:opener = s:Peek(a:result.parenStack)
            throw s:CreateError(a:result, s:ERROR_UNCLOSED_PAREN, l:opener.lineNo, l:opener.x)
        elseif a:result.mode ==# s:INDENT_MODE
            call s:CorrectParenTrail(a:result, 0)
        endif
    endif
    let a:result.success = 1
endfunction


function! s:ProcessError(result, err)
    let a:result.success = 0

    "" TODO: figure out how to attach error information to a throw
    "" let a:result.error = a:err
endfunction


function! s:ProcessText(text, mode, options)
    let l:result = s:CreateInitialResult(a:text, a:mode, a:options)

    try
        call map(copy(l:result.origLines), 's:ProcessLine(l:result, v:val)')
        call s:FinalizeResult(l:result)
    catch /PARINFER_ERROR/
        call s:ProcessError(l:result, {})
    endtry

    return l:result
endfunction

function! s:PublicResult(result)
    if ! a:result.success
        let l:result = {}
        let l:result.success = 0
        let l:result.text = a:result.origText
        let l:result.error = a:result.error
        return l:result
    endif

    let l:result = {}
    let l:result.success = 1
    let l:result.text = join(a:result.lines, s:NEWLINE)
    return l:result
endfunction

""------------------------------------------------------------------------------
"" Public API
""------------------------------------------------------------------------------

let s:PublicAPI = {}
let g:ParinferLib = s:PublicAPI

function! s:PublicAPI.IndentMode(text, options)
    let l:result = s:ProcessText(a:text, s:INDENT_MODE, a:options)
    return s:PublicResult(l:result)
endfunction

function! s:PublicAPI.ParenMode(text, options)
    let l:result = s:ProcessText(a:text, s:PAREN_MODE, a:options)
    return s:PublicResult(l:result)
endfunction
