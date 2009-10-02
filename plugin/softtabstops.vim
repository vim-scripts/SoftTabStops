" softtabstops.vim: Set typewriter like tabstops.
" Author: Hari Krishna (hari_vim at yahoo dot com)
" Last Change: 01-Oct-2009 @ 18:28
" Created:     17-May-2006
" Requires:    Vim-7.0, genutils.vim(2.0)
" Version:     1.0.6
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org//script.php?script_id=
" Description:
"   This plugin provides the ability to enter tabular data quickly in two
"   different ways:
"       - Set explicit stops at the columns.
"       - Enter a sample row and have the stops inferred from it.
"   The plugin provides a visual editor such that you can set explicit stops
"   with ease. The stops can be toggled using a mouse or keyboard. You can
"   toggle the plugin functionality on and off at the buffer or global
"   level.
" Usage:
"   - Use :STTgl to toggle using tabstops. This maps/unmaps <Tab> and <BS>.
"     When buffer-local tabs are enabled (the default), the maps are made
"     local to the current buffer, otherwise, the maps are global.
"   - Use :STEdit[!] to bring up an editor for setting explicit tab stops (or
"     to just view them). You would see three lines, two with numbers to guide
"     the column number and another to show the current tab stops. To toggle
"     stop at a any column, move cursor to the column and push spacebar or
"     directly click left mouse button. To save changes at the end, use :wq
"     command (or just :w, to leave the window open). You can press "q" to
"     quit when no changes have been made. When buffer-local tabs have been
"     enabled (the default), use bang to edit the global tabstops.
"   - Use STReset to reset the tabstops to one every 8 columns (or whatever
"     'tabstop' is set to), or STClear to clear all of them.
"   - By default the stops are lcoal to a buffer
"     (g:softtabstops_local_to_buffer setting is set). This helps to localize
"     the stops and maps to the current buffer of interest, but as a result
"     are not shared across buffers. The tabstops will be stored as a list of
"     columns in the buffer local variable called "b:softtabstops". To have
"     same set of stops for all buffers reset this setting and have the stops
"     stored in the global variable "g:softtabstops".
"   - You can manipulate softtabstops in any of these ways:
"       - directly, by using the Vim's |List| functions. You can even clone
"         (using |copy()| function) the global "g:softtabstops" to the buffer
"         local variable "b:softtabstops"
"       - using plugin commands :STAddTab, :STRemoveTab, :STReset and :STClear
"       - using visual editor started by :STEdit command
"   - When softtabstops is toggled on and off, the plugin doesn't try to
"     restore any prior maps for <Tab> and <BS>, this is because Vim doesn't
"     provide any means to capture a map completely. If the experimental
"     g:softtabstops_restore_original_map option is turned on the plugin
"     attempts to capture the maps by parsing the :map command output and the
"     maparg() result, but this method is very limited, and will not work for
"     many scenarios. If you have have your own insert mode mappings for <Tab>
"     and <BS> or use a plugin that defines them, make sure this plugin
"     doesn't conflict with them.
" Settings:
"   - g:softtabstops_local_to_buffer (default: 1). Set to 0 to make tabstops
"     shared globally by all buffers. This also makes :STTgl create global
"     maps.
"   - g:softtabstops_repeat_last_stop (default: 0). When set to 1, the plugin
"     repeats the entire sequence of tabstops when it needs to extend them.
"   - g:softtabstops_align_line_with_editor (default: 1): Set to 0 to avoid
"     repositioning the current line when the tab editor is opened.
"   - g:softtabstops_infer_tabstops (default: 1). Set to 0, if you don't want
"     the plugin to infer the tabstops based on the previous lines, when no
"     explicit tabstops are set (or existing ones are cleared using :STClear)
"   - g:softtabstops_infer_imm_nonblank_only (default: 1). Set to 0, if you
"     want the tabstops to be inferred from the previous line, only when there
"     are no blank lines between them.
"   - g:softtabstops_editor_guide_start_num (default: 0). Controls the column
"     number sequence in the tab editor. Should be between 0 to 9.
"   - g:softtabstops_editor_guide_end_num (default: 9). Controls the column
"     number sequence in the tab editor. Should be between 0 to 9 and greater
"     than g:softtabstops_editor_guide_start_num.
"   - g:softtabstops_restore_original_map (default: 0). Set to 1 to enable the
"     experimental feature to save and restore maps while toggling on and off.
" Limitations:
"   - Can only insert all spaces, not a mix of tabs and spaces.
" TODO:
"   - Imaps to add and remove tabs at the current column.
"   - Toggle highlighting of columns with tabstops.
"   - Do more with tabstops (investigate).
"     - Table navigation style insert mode maps:
"       - Shift+Tab, take cursor to the previous tab position (without modifing
"         buffer).
"       - Tab takes to the next field, if not the last field (otherwise inserts
"         space).

if exists('loaded_softtabstops')
  finish
endif
if v:version < 700
  echomsg 'softtabstops: You need at least Vim 7.0'
  finish
endif
if !exists('loaded_genutils')
  runtime plugin/genutils.vim
endif
if !exists('loaded_genutils') || loaded_genutils < 200
  echomsg 'softtabstops: You need a newer version of genutils.vim plugin'
  finish
endif

let g:loaded_softtabstops = 100

" Make sure line-continuations won't cause any problem. This will be restored
"   at the end
let s:save_cpo = &cpo
set cpo&vim
if !exists('g:softtabstops_local_to_buffer')
  let g:softtabstops_local_to_buffer = 1
endif

if !exists('g:softtabstops_repeat_last_stop')
  let g:softtabstops_repeat_last_stop = 0
endif

if !exists('g:softtabstops_align_line_with_editor')
  let g:softtabstops_align_line_with_editor = 1
endif

if !exists('g:softtabstops_infer_tabstops')
  let g:softtabstops_infer_tabstops = 1
endif

if !exists('g:softtabstops_infer_imm_nonblank_only')
  let g:softtabstops_infer_imm_nonblank_only = 1
endif

if !exists('g:softtabstops_editor_guide_start_num')
  let g:softtabstops_editor_guide_start_num = 0
endif

if !exists('g:softtabstops_editor_guide_end_num')
  let g:softtabstops_editor_guide_end_num = 9
endif

if !exists('g:softtabstops_restore_original_map')
  let g:softtabstops_restore_original_map = 0
endif

noremap <script> <silent> <Plug>SoftTabSetup :call softtabstops#ShowTabEditor()<CR>
if (! exists("no_plugin_maps") || ! no_plugin_maps) &&
      \ (! exists("no_softtabstops_maps") || ! no_softtabstops_maps)
  if !hasmapto('<Plug>SoftTabSetup', 'n')
    nmap <unique> <silent> <F6> <Plug>SoftTabSetup
  endif
endif

command! -bang STEdit :call softtabstops#ShowTabEditor('<bang>' == '!' ? 1 : 0)
command! -bang STEditor :STEdit<bang> <args>
command! STTgl :call softtabstops#ToggleSoftTabStop()
command! STReset :call softtabstops#ResetTabs()
command! STClear :call softtabstops#ClearTabs()
command! -nargs=+ STAddTab :call softtabstops#AddTabStop(<q-args>)
command! -nargs=+ -complete=customlist,softtabstops#TabStopRemoveComplete STRemoveTab
      \ :call softtabstops#RemoveTabStop(<q-args>)

" Restore cpo.
let &cpo = s:save_cpo
unlet s:save_cpo

" vim6:fdm=marker et sw=2
