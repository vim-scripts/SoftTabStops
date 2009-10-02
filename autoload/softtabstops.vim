" softtabstops.vim: See the plugin/softtabstops.vim

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim

if !exists('s:myBufNum')
  let s:myBufNum = -1
  let s:windowName = '[Soft Tabs]'
  let s:origBufNr = -1
  let s:origMaps = {}
endif

inoremap <expr> <Plug>SoftTabInsert softtabstops#TabToNext()
imap <expr> <Plug>SoftTabRemove softtabstops#BSToPrev()
inoremap <Plug>SoftTabBS <BS>
inoremap <expr> <Plug>SoftTabResetTabOpts <SID>ResetTabOptions()

" Basic tab management functions {{{
function! softtabstops#TabStopsAreLocal(bufnr)
  let localtabstops = a:bufnr != -1 ? getbufvar(a:bufnr, 'softtabstops') : ''
  let globaltabstops = exists('g:softtabstops') ? g:softtabstops : ''
  if (type(localtabstops) == 3 && localtabstops isnot globaltabstops) ||
        \ type(globaltabstops) != 3
    return 1
  else
    return 0
  endif
endfunction

function! softtabstops#GetTabStops(...)
  let bufnr = a:0 > 0 ? a:1+0 : bufnr('%')
  if softtabstops#TabStopsAreLocal(bufnr)
    let tabstops = getbufvar(bufnr, 'softtabstops')
  else
    let tabstops = g:softtabstops
  endif
  return type(tabstops) == 3 ? tabstops : softtabstops#DefaultStops(&columns)
endfunction

function! softtabstops#SetTabStops(ar, ...)
  let bufnr = a:0 > 0 ? a:1+0 : bufnr('%')
  if softtabstops#TabStopsAreLocal(bufnr)
    call setbufvar(bufnr, 'softtabstops', a:ar)
  else
    let g:softtabstops = a:ar
  endif
endfunction

function! softtabstops#ResetTabs()
  call softtabstops#SetTabStops(softtabstops#DefaultStops(&columns))
endfunction
 
function! softtabstops#ClearTabs()
  call softtabstops#SetTabStops([])
endfunction

function! softtabstops#DefaultStops(curCol)
  let tabstop = &tabstop
  let endCol = tabstop * ((a:curCol / tabstop)+1)
  return range(1+tabstop, 1+endCol, tabstop)
endfunction

function! softtabstops#RemoveTabStop(...)
  let tabstops = softtabstops#GetTabStops()
  for arg in (a:0 ? a:000 : [col('.')])
    if arg+0 == 0
      echohl ErrorMsg | echo "Invalid column: " . arg | echohl None
      continue
    endif
    let index = index(tabstops, arg+0)
    if index == -1
      echohl ErrorMsg | echo "No stop at column: " . arg | echohl None
    else
      call softtabstops#SetTabStops(remove(tabstops, index))
    endif
  endfor
endfunction

function! softtabstops#TabStopRemoveComplete(ArgLead, CmdLine, CursorPos)
  return filter(map(copy(softtabstops#GetTabStops()), "string(v:val)"),
        \ "stridx(v:val, a:ArgLead) != -1")
endfunction

function! softtabstops#AddTabStop(...)
  let i = -1
  let tabstops = softtabstops#GetTabStops()
  for arg in (a:0 ? a:000 : [col('.')])
    if arg !~ '^+\?\d\+$'
      echohl ErrorMsg | echo "Invalid column: " . arg | echohl None
      continue
    endif
    if arg[0] == '+'
      call add(tabstops, (tabstops[-1]+(arg[1:]+0)))
    else
      let arg = arg+0
      for c in tabstops
        let i = i + 1
        if c == arg
          return
        elseif c > arg
          call insert(tabstops, arg, i)
          return
        endif
      endfor
    endif
  endfor
  call add(tabstops, a:col)
endfunction

function! softtabstops#InferTabStops(line)
  if g:softtabstops_infer_imm_nonblank_only
    let prevNonBlank = (getline(a:line-1) !~ '^\s*$') ? a:line-1 : 0
  else
    let prevNonBlank = prevnonblank(a:line-1)
  endif

  if prevNonBlank > 0
    let prevLine = getline(prevNonBlank)
    " Look for at least two spaces to recognize it as a tab.
    let tabstops = filter(range(2, strlen(prevLine)),
          \ 'prevLine[v:val-1] != " " && prevLine[v:val-2] == " " && (v:val == 2 || prevLine[v:val-3] == " ")')
    return tabstops
  endif
  return []
endfunction

function! softtabstops#GetNextTabStop(curCol, prev)
  let tabstops = softtabstops#GetTabStops()
  let infered_tabstops = 0
  if len(tabstops) == 0 && g:softtabstops_infer_tabstops && line('.') > 1
    let tabstops = softtabstops#InferTabStop(line('.'))
    if len(tabstops) > 0
      let infered_tabstops = 1
    endif
  endif
  let _tabstops = len(tabstops) == 0 ? softtabstops#DefaultStops(a:curCol) :
        \ softtabstops#ExtendTabStops(tabstops, a:curCol)
  if !g:softtabstops_infer_tabstops && _tabstops isnot tabstops
    call softtabstops#SetTabStops(tabstops)
  endif
  let tabstops = _tabstops
  " Search for next stop
  let prevCol = 999999999
  for col in tabstops
    if a:prev && prevCol < a:curCol && a:curCol <= col
      return prevCol
    elseif !a:prev && a:curCol < col
      return col
    endif
    let prevCol = col
  endfor
  return -1
endfunction

function! softtabstops#ExtendTabStops(tabstops, curCol)
  let tabstops = a:tabstops
  if len(tabstops) == 0 || tabstops[-1] <= a:curCol
    if len(tabstops) == 0
      call extend(tabstops, softtabstops#DefaultStops(a:curCol))
    elseif g:softtabstops_repeat_last_stop || len(tabstops) == 1
      let lastTabLen = (tabstops[-1] - ((len(tabstops) > 1) ? tabstops[-2] : 1))
      let nextTabCnt = ((a:curCol - tabstops[-1]) % lastTabLen) + 1
      call extend(tabstops, map(range(1, nextTabCnt),
            \ 'tabstops[-1] + lastTabLen * v:val'))
    else
      while a:curCol >= tabstops[-1]
        " FIXME: Hack, remove if v:key patch is accepted. {{{
        if !exists('s:list_diff_hack')
          let s:list_diff_hack = {'prev_idx': 0}
          function! s:list_diff_hack.diff_val(val)
            let diff = a:val - self.prev_list[self.prev_idx]
            let self.prev_idx += 1
            return diff
          endfunction
          function! s:list_diff_hack.new(list)
            let new = copy(self)
            let new.prev_list = a:list
            return new
          endfunction
        endif
        let diff_hack = s:list_diff_hack.new(tabstops) " }}}
        let seq = map(tabstops[1:], 'diff_hack.diff_val(v:val)')
        " Use instead of above hack when v:key patch is accepted.
        "let seq = map(tabstops[1:], 'v:val-tabstops[v:key]')
        
        " sum() hack {{{
        if !exists('s:list_sum_hack')
          let s:list_sum_hack = {'prev_val': 0}
          function! s:list_sum_hack.add_val(val)
            let self.prev_val += a:val
            return self.prev_val
          endfunction
          function! s:list_sum_hack.new(init)
            let new = copy(self)
            let new.prev_val = a:init
            return new
          endfunction
        endif
        let sum_hack = s:list_sum_hack.new(tabstops[-1]) " }}}
        call extend(tabstops, map(seq, 'sum_hack.add_val(v:val)'))
      endwhile
    endif
  endif
  return tabstops
endfunction
" }}}

" <Tab> toggle {{{
let s:maps = {'<Tab>': '<Plug>SoftTabInsert', '<BS>': '<Plug>SoftTabRemove'}

function! softtabstops#ToggleSoftTabStop()
  if ! softtabstops#IsEnabled()
    if g:softtabstops_restore_original_map
      try
        let oldMaps = map(copy(s:maps), 'softtabstops#GetMapCommand(v:key, "i")')
      catch /^softtabstops:/
        echohl ErrorMsg | echo v:exception | echohl NONE
        return
      endtry
      let oldMapCmds = values(oldMaps)
      let hasBufferLocal = match(oldMapCmds, '<buffer>')
      if !g:softtabstops_local_to_buffer && hasBufferLocal != -1
        redraw | echohl ErrorMsg | echo 'Existing buffer local mapping "'.
              \ oldMapCmds[hasBufferLocal].
              \ "\" shadows global mapping, can't toggle softtabstops." |
              \ echohl NONE
        return 
      elseif g:softtabstops_local_to_buffer
        " Remove the non-<buffer> maps out, we don't need to remap them.
        call filter(oldMaps, 'stridx(v:val, "<buffer>") != -1')
      endif
      let s:origMaps = oldMaps
    endif
    for [lhs, rhs] in items(s:maps)
      exec 'imap' (g:softtabstops_local_to_buffer ? '<buffer>' : '') lhs rhs
    endfor
    let enabled = 1
  else
    for lhs in keys(s:maps)
      exec 'iunmap' (g:softtabstops_local_to_buffer ? '<buffer>' : '') lhs
    endfor
    if g:softtabstops_restore_original_map
      for mapCmd in values(s:origMaps)
        exec mapCmd
      endfor
    endif
    let enabled = 0
  endif
  redraw | echo 'SoftTabStops now' (enabled ? 'enabled' : 'disabled')
        \ (g:softtabstops_local_to_buffer ? '(current buffer only)' : '')
endfunction

function! softtabstops#IsEnabled()
  for [lhs, rhs] in items(s:maps)
    if maparg(lhs, 'i') == rhs
      return 1
    endif
  endfor
  return 0
endfunction

function! softtabstops#GetMapCommand(lhs, mode)
  " We might get multiple results.
  let mapResults = split(genutils#GetVimCmdOutput(a:mode.'map '.a:lhs), "\n")
  let mapPat = '^\(['.a:mode.' ]\{2}\) \V'. escape(a:lhs, '\').'\m \+\([*&@ ]\{2}\).*$'
  for mr in mapResults
    let matches = matchlist(mr, mapPat)
    if len(matches) > 0 " Found a match
      if matches[2] =~ '&'
        throw 'softtabstops:script-local mapping found: '.matches[0]
      endif
      " FIXME: This only handles a few cases. No <expr>, <script>, <silent>
      " support.
      let mapCmd = (matches[1] == '  ' ? ''  : (matches[1] == '! ' ? 'i' : a:mode))
            \    . ((matches[2] =~ '*') ? 'nore' : '')
            \    . 'map '
            \    . ((matches[2] =~ '@') ? '<buffer> ' : '')
            \    . a:lhs
            \    . (' '.maparg(a:lhs, a:mode))
      return mapCmd
    endif
  endfor
  return ''
endfunction
" }}}

" Visual tab editing {{{
function! softtabstops#ShowTabEditor(global)
  let s:origBufNr = bufnr('%')
  let s:origGlobal = a:global
  let tabstops = softtabstops#GetTabStops(a:global ? -1 : s:origBufNr)
  call s:SetupBuffer()
  if g:softtabstops_align_line_with_editor
    wincmd p
    normal! zt
    wincmd p
  endif
  call genutils#OptClearBuffer()
  let start = g:softtabstops_editor_guide_start_num
  let end = g:softtabstops_editor_guide_end_num
  if start < 0 || end > 9 || start >= end
    let start = 0
    let end = 9
  endif
  call append('$', join(map(range(0, ((&columns-1)/(end-start+1))),
        \ '(v:val.repeat(" ", 9))[:9]'), ''))
  call append('$', repeat(join(range(start,end), ''), ((&columns-1)/(end-start+1))+1))
  call append('$', repeat(' ', &columns))
  silent! 1d _ " The blank line.
  normal! G0
  for tst in tabstops
    call s:ToggleMark(tst)
  endfor
  exec 'resize' line('$')
  normal! z-
  setl nomodified
  setl nomodifiable
  nnoremap <buffer> <silent> q :q<CR>
endfunction

function! s:UpdateTabStops()
  if bufnr('%') == s:myBufNum
    let tabstr = getline(line('$'))
    if tabstr != ''
      let tabstops = []
      " Determine the tab stops.
      let tabl = split(tabstr, 'v\zs', 1)
      let tabCnt = 0
      for ea in tabl
        if ea !~ 'v$'
          " Last token doesn't have a tabstop following it.
          break
        endif
        call add(tabstops, strlen(ea) +
              \ (tabCnt == 0 ? 0 : tabstops[tabCnt-1]))
        let tabCnt = tabCnt + 1
      endfor
      call softtabstops#SetTabStops(tabstops, s:origGlobal ? -1 : s:origBufNr)
    endif
  endif
  setl nomodified
endfunction

function! s:SetupBuffer()
  let origWinnr = winnr()
  let _isf = &isfname
  let _splitbelow = &splitbelow
  set nosplitbelow
  try
    if s:myBufNum == -1
      " Temporarily modify isfname to avoid treating the name as a pattern.
      set isfname-=\
      set isfname-=[
      if exists('+shellslash')
        call genutils#OpenWinNoEa("3sp \\\\". escape(s:windowName, ' '))
      else
        call genutils#OpenWinNoEa("3sp \\". escape(s:windowName, ' '))
      endif
      let s:myBufNum = bufnr('%')
    else
      let winnr = bufwinnr(s:myBufNum)
      if winnr == -1
        call genutils#OpenWinNoEa('3sb '. s:myBufNum)
      else
        let wasVisible = 1
        exec winnr 'wincmd w'
      endif
    endif
  finally
    let &isfname = _isf
    let &splitbelow = _splitbelow
  endtry

  aug SoftTabs
    au!
    exec 'au BufWriteCmd ' . escape(s:windowName, '\[*^$. ') .' :call <SID>UpdateTabStops()'
  aug END

  call genutils#SetupScratchBuffer()
  setlocal nowrap
  setlocal winfixheight
  setlocal buftype= " For the BufWriteCmd.
  nnoremap <buffer> <silent> <Space> :call <SID>ToggleMark(col('.'))<CR>
  nmap <buffer> <silent> <LeftMouse> <LeftMouse><Space>
  nnoremap <buffer> <Tab> w
  nnoremap <buffer> <S-Tab> b
endfunction

function! s:ToggleMark(col)
  if line('.') != line('$')
    return
  endif
  let curCol = col('.')
  " Restrict the replacement to the second line, always.
  setl modifiable
  try
    silent! exec '$s/\%'.a:col.'c./\=submatch(0)==" "?"v":" "'
  finally
    setl nomodifiable
  endtry
  exec 'normal' curCol.'|'
endfunction
" }}}

" Tab navigation {{{
function! softtabstops#TabToNext()
  let curCol = col('.')
  let curLine = getline('.')
  let nextTabStop = softtabstops#GetNextTabStop(curCol, 0)
  " If this is a new row, we can just insert the blanks, but if it is an
  " existing row, we have to be more clever.
  if strlen(curLine) > curCol
    " Find the next non-space character.
    let c = curCol
    while curLine[c-1] == ' ' && c < nextTabStop
      let c = c + 1
    endwhile
  else
    let c = curCol
  endif
  let fill = repeat(' ', (nextTabStop - c))
  if c > curCol
    let fill = fill. repeat("\<Right>", (c - curCol))
  endif
  return fill
  return "\<Tab>"
endfunction

function! softtabstops#BSToPrev()
  let curCol = col('.')
  let curLine = getline('.')
  let prevTabStop = softtabstops#GetNextTabStop(curCol, 1)
  let prevTabStop = prevTabStop == -1 ? 1 : prevTabStop
  " Do special handling only when there are some spaces in the front.
  if curLine[curCol-2] == ' ' && curCol > prevTabStop
    " Find the column that is not empty going backwards.
    for c in range(curCol-1, prevTabStop, -1)
      if curLine[c-1] != ' '
        let prevTabStop = c+1
        break
      endif
    endfor
    if curCol > prevTabStop
      let s:_softtabstop = &l:softtabstop | setlocal softtabstop=0
      let s:_backspace = &l:backspace | set backspace+=start
      return repeat("\<Plug>SoftTabBS", (curCol - prevTabStop))."\<Plug>SoftTabResetTabOpts"
    endif
  endif
  return "\<Plug>SoftTabBS"
endfunction

function! s:ResetTabOptions()
  let &l:softtabstop = s:_softtabstop | unlet s:_softtabstop
  let &l:backspace = s:_backspace | unlet s:_backspace
  return ''
endfunction
" }}}

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker et sw=2
