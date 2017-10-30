" ============================================================================
" File:        fswitch.vim
"
" Description: Vim global plugin that provides decent companion source file
"              switching
"
" Maintainer:  Derek Wyatt <derek at myfirstnamemylastname dot org>
"
" Last Change: October 30th 2017
"
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================
if exists('g:loaded_fswitch') || exists("g:disable_fswitch") || &cp || version < 700
    finish
endif
let g:loaded_fswitch = 1

" Version
let s:fswitch_version = '0.9.6'

" Get the path separator right
let s:os_slash = &ssl == 0 && (has("win16") || has("win32") || has("win64")) ? '\' : '/'

" Default locations - appended to buffer locations unless otherwise specified
let s:fswitch_global_locs = '.' . s:os_slash

"
" The autocmds we set up to set up the buffer variables for us.
"
augroup fswitch_au_group
    au!
    au BufEnter *.c    call fswitch#FTInit('h',       'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.cc   call fswitch#FTInit('hh',      'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.cpp  call fswitch#FTInit('hpp,h',   'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.cxx  call fswitch#FTInit('hxx',     'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.C    call fswitch#FTInit('H',       'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.m    call fswitch#FTInit('h',       'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.h    call fswitch#FTInit('c,cpp,m', 'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.hh   call fswitch#FTInit('cc',      'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.hpp  call fswitch#FTInit('cpp',     'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.hxx  call fswitch#FTInit('cxx',     'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.H    call fswitch#FTInit('C',       'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
augroup END

"
" The mappings used to do the good work
"
com! FSHere       :call fswitch#FSwitch('%', '')
com! FSRight      :call fswitch#FSwitch('%', 'wincmd l')
com! FSSplitRight :call fswitch#FSwitch('%', 'let curspr=&spr | set nospr | vsplit | wincmd l | if curspr | set spr | endif')
com! FSLeft       :call fswitch#FSwitch('%', 'wincmd h')
com! FSSplitLeft  :call fswitch#FSwitch('%', 'let curspr=&spr | set nospr | vsplit | if curspr | set spr | endif')
com! FSAbove      :call fswitch#FSwitch('%', 'wincmd k')
com! FSSplitAbove :call fswitch#FSwitch('%', 'let cursb=&sb | set nosb | split | if cursb | set sb | endif')
com! FSBelow      :call fswitch#FSwitch('%', 'wincmd j')
com! FSSplitBelow :call fswitch#FSwitch('%', 'let cursb=&sb | set nosb | split | wincmd j | if cursb | set sb | endif')
